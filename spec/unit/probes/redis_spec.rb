require "spec_helper"

module Skylight
  module Probes
    describe "Redis:Probe", :redis_probe, :probes do
      it "is installed" do
        reg = Skylight::Probes.installed.fetch(:redis)
        expect(reg.const_name).to eq("Redis")
        expect(reg.require_paths).to eq(["redis"])
        expect(reg.probe).to be_a(Skylight::Probes::Redis::Probe)
      end

      it "defers to the redis_client probe on redis 5+" do
        skip "redis < 5 is not built on redis-client" unless defined?(::RedisClient) && ::Redis::Client < ::RedisClient

        expect(Skylight::Probes.installed).to have_key(:redis_client)
        expect(::Redis::Client.ancestors).not_to include(Skylight::Probes::Redis::ClientInstrumentation)
        expect(::Redis.ancestors).not_to include(Skylight::Probes::Redis::Instrumentation)
      end

      it "ignores a Redis namespace that isn't the redis gem" do
        stub_const("Redis", Module.new)

        expect(Skylight).not_to receive(:error)

        Skylight::Probes::Redis::Probe.new.install
      end

      it "ignores a versioned Redis namespace that isn't the redis gem" do
        stub_const("Redis", Module.new.tap { |mod| mod.const_set(:VERSION, "9.9.9") })

        expect(Skylight).not_to receive(:error)

        expect { Skylight::Probes::Redis::Probe.new.install }.not_to raise_error
      end
    end
  end
end
