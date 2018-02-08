require 'spec_helper'
require 'skylight/core/instrumenter'

if defined?(Sinatra)
  describe 'Sinatra integration', :sinatra_probe, :agent do
    include Rack::Test::Methods

    before do
      TestNamespace.mock! do |trace|
        @current_trace = trace
      end
    end

    after do
      TestNamespace.stop!
    end

    class SinatraTest < ::Sinatra::Base
      use TestNamespace::Middleware

      disable :show_exceptions

      template :hello do
        "Hello from named template"
      end

      get "/named-template" do
        erb :hello
      end

      get "/inline-template" do
        erb "Hello from inline template"
      end
    end

    def app
      SinatraTest
    end

    it "creates a Trace for a Sinatra app" do
        expect(TestNamespace).to receive(:trace).with("Rack", "app.rack.request", nil, nil).and_call_original

      get "/named-template"
      expect(@current_trace.endpoint).to eq("GET /named-template")
      expect(last_response.body).to eq("Hello from named template")
    end

    it "instruments named templates" do
      expect(TestNamespace).to receive(:instrument).with(
        category: "view.render.template",
        title: "hello"
      ).and_call_original

      get "/named-template"

      expect(@current_trace.endpoint).to eq("GET /named-template")
    end

    it "instruments inline templates" do
      expect(TestNamespace).to receive(:instrument).with(
        category: "view.render.template",
        title: "Inline template (erb)"
      ).and_call_original

      get "/inline-template"

      expect(@current_trace.endpoint).to eq("GET /inline-template")
    end
  end
end
