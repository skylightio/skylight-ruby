require "spec_helper"

module Skylight
  describe "Normalizers", "finish_handler.coach", :agent do
    let(:event) { { middleware: "Auth" } }

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(event)
      expect(trace.endpoint).to eq("Auth")
      expect(trace.segment).to be_nil
    end

    it "adds segment when response is an error" do
      normalize(event)
      normalize_after(event.merge(response: { status: 500 }))

      expect(trace.endpoint).to eq("Auth")
      expect(trace.segment).to eq("error")
    end
  end
end
