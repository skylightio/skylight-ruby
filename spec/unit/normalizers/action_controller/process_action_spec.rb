require "spec_helper"

module Skylight
  # Ideally this wouldn't be a unit test, since we rely on the instrumenter cache
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
      normalize(controller: "FooController", action: "bar", format: "html")
      expect(trace.endpoint).to eq("FooController#bar")
    end

    it "updates with additional format information" do
      normalize(controller: "FooController", action: "bar", format: "json")
      expect(trace.endpoint).to eq("FooController#bar")
      normalize_after(
        controller: "FooController",
        action: "bar",
        format: "*/*",
        sk_rendered_format: "json",
        sk_variant: [:tablet],
        status: 200
      )
      expect(trace.endpoint).to eq("FooController#bar")
      expect(trace.segment).to eq("json+tablet")
    end
  end
end
