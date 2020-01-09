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

      it "wraps Redis::Client#call" do
        # This test is somewhat lame
        expect(::Redis::Client.instance_methods).to include(:call_without_sk)
      end
    end
  end
end
