require 'spec_helper'

module Skylight
  describe "Normalizers", "coach.handler.finish", :agent do

    before :each do
      @original_enable_segments = config.enable_segments?
      config.set(:enable_segments, true)
    end

    after :each do
      config.set(:enable_segments, @original_enable_segments)
    end

    let(:enable_segments) { false }
    let(:event) { { middleware: "Auth" } }

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(event)
      expect(trace.endpoint).to eq("Auth")
    end

    it "adds segment when response is an error" do
      normalize(event)
      normalize_after(event.merge(response: { status: 500 }))

      expect(trace.endpoint).to eq("Auth<sk-segment>error</sk-segment>")
    end

    it "adds segment when Coach logs :skylight_segment_* key" do
      normalize(event)
      normalize_after(event.merge(
        metadata: { random_key: true, skylight_segment_admin: true }
      ))

      expect(trace.endpoint).to eq("Auth<sk-segment>admin</sk-segment>")
    end

  end
end
