require "spec_helper"

module Skylight
  describe "Normalizers", "coach.middleware.finish", :agent do

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(middleware: "Auth")
      expect(trace.endpoint).to eq("Auth")
    end

  end
end
