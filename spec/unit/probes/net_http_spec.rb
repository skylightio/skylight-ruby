require "spec_helper"

module Skylight
  module Probes
    describe "NetHTTP:Probe", :net_http_probe, :probes do
      it "is installed" do
        reg = Skylight::Probes.installed.fetch(:net_http)
        expect(reg.const_name).to eq("Net::HTTP")
        expect(reg.require_paths).to eq(["net/http"])
        expect(reg.probe).to be_a(Skylight::Probes::NetHTTP::Probe)
      end

      it "wraps Net::HTTP#request" do
        # This test is somewhat lame
        expect(Net::HTTP.instance_methods).to include(:request_without_sk)
      end
    end
  end
end
