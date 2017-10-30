require 'spec_helper'

describe 'Redis integration', :redis_probe, :agent do

  before(:each) do
    @redis = Redis.new
  end

  it "instruments redis commands" do
    expected = {
      category: "db.redis.command",
      title:    "LRANGE"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.lrange("cache:all:the:things", 0, -1)
  end

  it "does not instrument the AUTH command" do
    expect(Skylight).to_not receive(:instrument)

    @redis.auth("secret")
  end

  it "instruments pipelining" do
    expected = {
      category: "db.redis.pipelined",
      title:    "PIPELINE"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.pipelined do
      @redis.lrange("cache:all:the:things", 0, -1)
    end
  end

  it "instruments multi" do
    expected = {
      category: "db.redis.multi",
      title:    "MULTI"
    }

    expect(Skylight).to receive(:instrument).with(expected).and_call_original

    @redis.multi do
      @redis.lrange("cache:all:the:things", 0, -1)
    end
  end

end
