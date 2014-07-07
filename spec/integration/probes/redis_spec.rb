require 'spec_helper'

describe 'Redis integration', :redis_probe, :redis, :agent do

  before(:each) do
    @redis = Redis.new
  end

  it "instruments redis commands" do
    expected = {
      category: "db.redis.command",
      title:    "LRANGE"
    }

    Skylight.should_receive(:instrument).with(expected).and_call_original

    @redis.lrange("cache:all:the:things", 0, -1)
  end

  it "does not instrument the AUTH command" do
    Skylight.should_not_receive(:instrument)

    @redis.auth("secret")
  end

end
