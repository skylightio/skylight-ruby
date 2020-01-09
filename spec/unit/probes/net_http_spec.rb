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

      it "adds instrumentation module" do
        # This test is somewhat lame
        expect(Net::HTTP.ancestors).to include(::Skylight::Probes::NetHTTP::Instrumentation)
      end
    end
  end
end
