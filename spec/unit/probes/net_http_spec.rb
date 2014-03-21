require 'spec_helper'

module Skylight
  module Probes
    describe "NetHTTP:Probe", :net_http_probe, :probes, :agent do

      it "is registered" do
        reg = Skylight::Probes.installed["Net::HTTP"]
        reg.klass_name.should == "Net::HTTP"
        reg.require_paths.should == ["net/http"]
        reg.probe.should be_a(Skylight::Probes::NetHTTP::Probe)
      end

      it "wraps Net::HTTP#request" do
        # This test is somewhat lame
        Net::HTTP.instance_methods.should include(:request_without_sk)
      end

    end
  end
end