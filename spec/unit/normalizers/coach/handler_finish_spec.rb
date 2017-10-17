require 'spec_helper'

module Skylight
  describe "Normalizers", "coach.handler.finish", :agent do

    # Coach instrumentation is only available in Ruby 2+
    before :each do
      skip "only available in Ruby 2+" unless RUBY_VERSION.split.first.to_i > 1
    end

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

  end
end
