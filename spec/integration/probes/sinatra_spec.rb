require 'spec_helper'
require 'skylight/instrumenter'
begin
  require 'sinatra/namespace'
rescue LoadError
  # ignore
end

if defined?(Sinatra)
  describe 'Sinatra integration', :sinatra_probe, :agent do
    include Rack::Test::Methods

    before do
      Skylight::Instrumenter.mock! do |trace|
        @current_trace = trace
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

      if defined?(Sinatra::Namespace)
        register Sinatra::Namespace
        namespace "/namespace" do
          get "/action" do
            "Hello world!"
          end

          get %r{/get/([a-z]+)} do
            "Hello world Regexp!"
          end
        end
      end
    end

    def app
      SinatraTest
    end

    it "creates a Trace for a Sinatra app" do
      expect(Skylight).to receive(:trace).with("Rack", "app.rack.request").and_call_original

      get "/named-template"
      expect(@current_trace.endpoint).to eq("GET /named-template")
      expect(last_response.body).to eq("Hello from named template")
    end

    it "instruments named templates" do
      expect(Skylight).to receive(:instrument).with(
        category: "view.render.template",
        title: "hello"
      ).and_call_original

      get "/named-template"

      expect(@current_trace.endpoint).to eq("GET /named-template")
    end

    it "instruments inline templates" do
      expect(Skylight).to receive(:instrument).with(
        category: "view.render.template",
        title: "Inline template (erb)"
      ).and_call_original

      get "/inline-template"

      expect(@current_trace.endpoint).to eq("GET /inline-template")
    end

    if defined?(Sinatra::Namespace)
      it "takes namespace into account" do
        expect(Skylight).to receive(:trace).with("Rack", "app.rack.request").and_call_original

        get "/namespace/action"
        expect(@current_trace.endpoint).to eq("GET /namespace/action")
        expect(last_response.body).to eq("Hello world!")
      end

      it "takes namespace into account with regexp paths" do
        expect(Skylight).to receive(:trace).with("Rack", "app.rack.request").and_call_original

        get "/namespace/get/abc"
        expect(@current_trace.endpoint).to eq("GET <sk-regex>%r{^(?-mix:(?-mix:\\/namespace)(?-mix:\\/get\\/([a-z]+)))$}</sk-regex>")
        expect(last_response.body).to eq("Hello world Regexp!")
      end
    end
  end
end
