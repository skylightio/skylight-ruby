require 'spec_helper'

module Skylight
  describe "Normalizers", "coach.middleware.finish", :agent do

    # Coach instrumentation is only available in Ruby 2+
    before :each do
      skip "only available in Ruby 2+" unless RUBY_VERSION.split.first.to_i > 1
    end

    it "updates the trace's endpoint" do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(middleware: "Auth")
      expect(trace.endpoint).to eq("Auth")
    end

  end
end
