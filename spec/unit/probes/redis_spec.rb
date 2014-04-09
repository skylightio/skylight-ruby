require 'spec_helper'

module Skylight
  module Probes
    describe "Redis:Probe", :redis_probe, :probes do

      it "is registered" do
        reg = Skylight::Probes.installed["Redis"]
        reg.klass_name.should == "Redis"
        reg.require_paths.should == ["redis"]
        reg.probe.should be_a(Skylight::Probes::Redis::Probe)
      end

      it "wraps Redis::Client#call" do
        # This test is somewhat lame
        ::Redis::Client.instance_methods.should include(:call_without_sk)
      end

    end
  end
end
