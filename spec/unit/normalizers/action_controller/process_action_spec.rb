require 'spec_helper'

module Skylight
  describe "Normalizers", "process_action.action_controller", :agent do

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(controller: "foo", action: "bar", format: "html")
      expect(trace.endpoint).to eq("foo#bar")
    end

    it "updates with additional format information" do
      normalize(controller: "foo", action: "bar", format: "json")
      expect(trace.endpoint).to eq("foo#bar")
      normalize_after(controller: "foo", action: "bar", format: "json", variant: [:tablet])
      expect(trace.endpoint).to eq("foo#bar<sk-format>json+tablet</sk-format>")
    end

  end
end
