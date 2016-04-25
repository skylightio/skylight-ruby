require 'spec_helper'

module Skylight
  describe "Normalizers", "process_action.action_controller", :agent do

    before :each do
      @original_enable_segments = config.enable_segments?
      config.set(:enable_segments, true)
    end

    after :each do
      config.set(:enable_segments, @original_enable_segments)
    end

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(controller: "foo", action: "bar", format: "html")
      expect(trace.endpoint).to eq("foo#bar")
    end

    it "updates with additional format information" do
      normalize(controller: "foo", action: "bar", format: "json")
      expect(trace.endpoint).to eq("foo#bar")
      normalize_after(controller: "foo", action: "bar", format: "*/*", rendered_format: 'json', variant: [:tablet], status: 200)
      expect(trace.endpoint).to eq("foo#bar<sk-segment>json+tablet</sk-segment>")
    end

  end
end
