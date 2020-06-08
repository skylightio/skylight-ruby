require "spec_helper"

module Skylight
  module Probes
    describe "Faraday:Probe", :faraday_probe, :probes do
      it "is installed" do
        reg = Skylight::Probes.installed.fetch(:faraday)
        expect(reg.const_name).to eq("Faraday")
        expect(reg.require_paths).to eq(["faraday"])
        expect(reg.probe).to be_a(Skylight::Probes::Faraday::Probe)
      end

      it "adds instrumentation module" do
        expect(::Faraday::Connection.ancestors).to include(::Skylight::Probes::Faraday::Instrumentation)
      end
    end
  end
end
