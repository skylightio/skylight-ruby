require "spec_helper"

describe "Redis integration", :redis_probe, :agent do
  before(:each) { @redis = Redis.new }

  it "instruments redis commands" do
    expected = { category: "db.redis.command", title: "LRANGE", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.lrange("cache:all:the:things", 0, -1)
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

    @redis.pipelined { @redis.lrange("cache:all:the:things", 0, -1) }
  end

  it "instruments multi" do
    expected = { category: "db.redis.multi", title: "MULTI", internal: true }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original
    allow(Skylight).to receive(:instrument).and_call_original

    @redis.multi { @redis.lrange("cache:all:the:things", 0, -1) }
  end
end
