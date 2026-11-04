require "spec_helper"

module Skylight
  module Probes
    describe "RedisClient:Probe", :redis_client_probe, :probes do
      it "is installed" do
        reg = Skylight::Probes.installed.fetch(:redis_client)
        expect(reg.const_name).to eq("RedisClient")
        expect(reg.require_paths).to eq(%w[redis-client redis_client])
        expect(reg.probe).to be_a(Skylight::Probes::Redis::RedisClient::Probe)
      end

      it "is enabled by the redis probe" do
        expect(Skylight::Probes.available).to have_key("redis")
        expect(Skylight::Probes.available).not_to have_key("redis_client")
      end

      it "registers the middleware globally" do
        expect(::RedisClient::Middlewares.ancestors).to include(Skylight::Probes::Redis::RedisClient::Middleware)
      end

      it "instruments connecting without changing its visibility" do
        expect(::RedisClient.ancestors).to include(Skylight::Probes::Redis::RedisClient::ConnectInstrumentation)
        expect(::RedisClient.private_method_defined?(:connect)).to be(true)
      end
    end
  end
end
