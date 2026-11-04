require "spec_helper"

describe "Redis integration", :redis_probe, :agent do
  before(:each) do
    @redis = Redis.new
    # Connect up front, so examples only see the commands they issue
    @redis.ping
  end

  it "instruments redis commands" do
    expected = { category: "db.redis.command", title: "LRANGE", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.lrange("cache:all:the:things", 0, -1)
  end

  it "instruments blocking commands" do
    expected = { category: "db.redis.command", title: "BLPOP", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.blpop("skylight:redis:empty", timeout: 0.01)
  end

  it "does not instrument the AUTH command" do
    expect(Skylight).to_not receive(:instrument)

    begin
      @redis.auth("secret")
    rescue Redis::CommandError => e
      expect(e.message).to start_with("ERR AUTH <password> called without any password configured")
    end
  end

  it "instruments pipelining" do
    expected = { category: "db.redis.pipelined", title: "PIPELINE", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original
    allow(Skylight).to receive(:instrument).and_call_original

    @redis.pipelined { |pipeline| pipeline.lrange("cache:all:the:things", 0, -1) }
  end

  it "instruments multi" do
    expected = { category: "db.redis.multi", title: "MULTI", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original
    allow(Skylight).to receive(:instrument).and_call_original

    @redis.multi { |transaction| transaction.lrange("cache:all:the:things", 0, -1) }
  end
end

describe "Redis connection integration", :redis_probe, :agent do
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
    skip "redis < 5 is not built on redis-client" unless defined?(RedisClient) && Redis::Client < RedisClient

    # Without a password, the handshake is just SELECT; nothing marks it as part of connecting
    redis = Redis.new(db: 1)

    redis.ping

    expect(redis_spans).to eq([%w[db.redis.connect CONNECT], %w[db.redis.command PING]])
  ensure
    redis&.close
  end
end
