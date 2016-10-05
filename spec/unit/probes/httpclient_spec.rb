require 'spec_helper'

module Skylight
  module Probes
    describe "HTTPClient:Probe", :httpclient_probe, :probes do

      it "is registered" do
        reg = Skylight::Probes.installed["HTTPClient"]
        expect(reg.klass_name).to eq("HTTPClient")
        expect(reg.require_paths).to eq(["httpclient"])
        expect(reg.probe).to be_a(Skylight::Probes::HTTPClient::Probe)
      end

      it "wraps HTTPClient#do_request" do
        # This test is somewhat lame
        expect(::HTTPClient.private_instance_methods).to include(:do_request_without_sk)
      end

    end
  end
end
