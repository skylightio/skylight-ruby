require "spec_helper"

describe "RedisClient integration", :redis_client_probe, :agent do
  before(:each) do
    @redis = RedisClient.new
    # Connect up front, so examples only see the commands they issue
    @redis.call("ping")
  end

  after(:each) { @redis.close }

  def command(title)
    { category: "db.redis.command", title: title, internal: true }
  end

  it "instruments commands" do
    expect(Skylight).to receive(:instrument).with(command("LRANGE")).and_call_original

    @redis.call("lrange", "cache:all:the:things", 0, -1)
  end

  it "instruments call_v, call_once and blocking calls" do
    expect(Skylight).to receive(:instrument).with(command("GET")).and_call_original
    expect(Skylight).to receive(:instrument).with(command("EXISTS")).and_call_original
    expect(Skylight).to receive(:instrument).with(command("BLPOP")).and_call_original

    @redis.call_v(%w[get skylight:redis_client:key])
    @redis.call_once("exists", "skylight:redis_client:key")
    @redis.blocking_call(1, "blpop", "skylight:redis_client:empty", "0.01")
  end

  it "does not instrument the AUTH command" do
    expect(Skylight).not_to receive(:instrument)

    expect { @redis.call("auth", "secret") }.to raise_error(
      RedisClient::CommandError,
      /AUTH <password> called without any password configured/
    )
  end

  it "instruments pipelining" do
    expected = { category: "db.redis.pipelined", title: "PIPELINE", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.pipelined do |pipeline|
      pipeline.call("lrange", "cache:all:the:things", 0, -1)
      pipeline.call("get", "skylight:redis_client:key")
    end
  end

  it "does not instrument empty pipelines" do
    expect(Skylight).not_to receive(:instrument)

    @redis.pipelined { |_pipeline| nil }
  end

  it "instruments multi" do
    expected = { category: "db.redis.multi", title: "MULTI", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.multi { |transaction| transaction.call("get", "skylight:redis_client:key") }
  end

  it "instruments multi with watch" do
    expected = { category: "db.redis.multi", title: "MULTI", internal: true }

    expect(Skylight).to receive(:instrument).with(command("WATCH")).and_call_original
    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.multi(watch: ["skylight:redis_client:key"]) do |transaction|
      transaction.call("get", "skylight:redis_client:key")
    end
  end

  it "instruments pooled clients" do
    pool = RedisClient.config.new_pool(size: 1)
    pool.call("ping")

    expect(Skylight).to receive(:instrument).with(command("GET")).and_call_original

    pool.call("get", "skylight:redis_client:key")
  ensure
    pool&.close
  end
end

describe "RedisClient connection integration", :redis_client_probe, :agent do
  around do |example|
    Skylight.mock!
    Skylight.trace("Rack") { example.run }
  end

  after { Skylight.stop! }

  let(:trace) { Skylight.instrumenter.current_trace }

  def redis_spans
    trace.filter_spans { |span| span[:cat].start_with?("db.redis") }.map { |span| [span[:cat], span[:title]] }
  end

  it "records connecting as a single span, including the handshake" do
    # db: 1 sends HELLO and SELECT as a pipeline when connecting
    client = RedisClient.new(db: 1)

    client.call("ping")
    client.call("ping")

    expect(redis_spans).to eq([%w[db.redis.connect CONNECT], %w[db.redis.command PING], %w[db.redis.command PING]])
  ensure
    client&.close
  end

  it "records reconnecting" do
    client = RedisClient.new

    client.call("ping")
    client.close
    client.call("ping")

    expect(redis_spans).to eq(
      [%w[db.redis.connect CONNECT], %w[db.redis.command PING], %w[db.redis.connect CONNECT], %w[db.redis.command PING]]
    )
  ensure
    client&.close
  end
end
