require 'spec_helper'
require 'skylight/instrumenter'

if defined?(Sinatra)
  describe 'Sinatra integration', :sinatra_probe, :agent do
    include Rack::Test::Methods

    before do
      Skylight::Instrumenter.mock! do |trace|
        expect(trace.endpoint).to eq(@expected_endpoint)
      end
    end

    after do
      Skylight::Instrumenter.stop!
    end

    class SinatraTest < ::Sinatra::Base
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
      @expected_endpoint = "GET /named-template"

      expect(Skylight).to receive(:trace).with("Rack", "app.rack.request").and_call_original

      get "/named-template"
      expect(last_response.body).to eq("Hello from named template")
    end

    it "instruments named templates" do
      @expected_endpoint = "GET /named-template"

      expect(Skylight).to receive(:instrument).with(
        category: "view.render.template",
        title: "hello"
      ).and_call_original

      get "/named-template"
    end

    it "instruments inline templates" do
      @expected_endpoint = "GET /inline-template"

      expect(Skylight).to receive(:instrument).with(
        category: "view.render.template",
        title: "Inline template (erb)"
      ).and_call_original

      get "/inline-template"
    end
  end
end
