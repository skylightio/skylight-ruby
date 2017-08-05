require 'spec_helper'

module Skylight
  describe "Normalizers", "coach.middleware.finish", :agent do

    before :each do
      @original_enable_segments = config.enable_segments?
      config.set(:enable_segments, true)
    end

    after :each do
      config.set(:enable_segments, @original_enable_segments)
    end

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(middleware: "Auth")
      expect(trace.endpoint).to eq("Auth")
    end

  end
end
