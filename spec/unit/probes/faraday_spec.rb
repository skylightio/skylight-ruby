require "spec_helper"

module Skylight
  module Probes
    describe "Faraday:Probe", :faraday_probe, :probes do
      it "is registered" do
        reg = Skylight::Probes.installed["Faraday"]
        expect(reg.klass_name).to eq("Faraday")
        expect(reg.require_paths).to eq(["faraday"])
        expect(reg.probe).to be_a(Skylight::Probes::Faraday::Probe)
      end

      it "wraps Faraday#initialize" do
        expect(::Faraday::Connection.private_instance_methods).to include(:initialize_without_sk)
      end
    end
  end
end
