# frozen_string_literal: true

require "spec_helper"
module Skylight
  describe "Normalizers", "process_middleware.action_dispatch", :agent do
    [Class.new, Module.new, -> {  }].map(&:to_s).each do |anonymous_middleware|
      specify do
        expect(trace).to receive(:endpoint=).and_call_original
        normalize(middleware: anonymous_middleware)
        expect(trace.endpoint).to eq("Anonymous Middleware")
      end
    end

    specify do
      expect(trace).to receive(:endpoint=).and_call_original
      normalize(middleware: "MyMiddleware")
      expect(trace.endpoint).to eq("MyMiddleware")
    end
  end
end
