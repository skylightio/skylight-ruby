require "spec_helper"

module Skylight
  module Probes
    describe "HTTPClient:Probe", :httpclient_probe, :probes do
      it "is installed" do
        reg = Skylight::Probes.installed.fetch(:httpclient)
        expect(reg.const_name).to eq("HTTPClient")
        expect(reg.require_paths).to eq(["httpclient"])
        expect(reg.probe).to be_a(Skylight::Probes::HTTPClient::Probe)
      end

      it "adds instrumentation module" do
        # This test is somewhat lame
        expect(::HTTPClient.ancestors).to include(::Skylight::Probes::HTTPClient::Instrumentation)
      end
    end
  end
end
