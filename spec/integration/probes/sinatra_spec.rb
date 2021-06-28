require "spec_helper"
require "skylight/instrumenter"

if defined?(Sinatra)
  describe "Sinatra integration", :sinatra_probe, :agent do
    include Rack::Test::Methods

    before :all do
      Skylight.probe(:sinatra_add_middleware)
    end

    before do
      Skylight.mock!(enable_source_locations: true) { |trace| @current_trace = trace }

      stub_const(
        "SinatraTest",
        Class.new(::Sinatra::Base) do
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

          get "/haml-template" do
            haml :hello
          end

          set :raise_errors, true
        end
      )
    end

    after { Skylight.stop! }

    def app
      SinatraTest
    end

    it "creates a Trace for a Sinatra app" do
      get "/named-template"
      expect(@current_trace.endpoint).to eq("GET /named-template")
      expect(@current_trace.component).to eq(URI.encode_www_form_component("web:production"))
      expect(@current_trace.mock_spans[0][:cat]).to eq("app.rack.request")
      expect(@current_trace.mock_spans[0][:meta]).to eq({ source_location: Skylight::Trace::SYNTHETIC })
      expect(last_response.body).to eq("Hello from named template")
    end

    it "instruments named templates" do
      expect(Skylight).to receive(:instrument).with(category: "view.render.template", title: "hello").and_call_original
      allow(Skylight).to receive(:instrument).and_call_original

      get "/named-template"

      expect(@current_trace.endpoint).to eq("GET /named-template")
    end

    it "instruments haml templates" do
      expect(Skylight).to receive(:instrument).with(category: "view.render.template", title: "hello").and_call_original
      allow(Skylight).to receive(:instrument).and_call_original

      get "/haml-template"

      expect(@current_trace.endpoint).to eq("GET /haml-template")
    end

    it "instruments inline templates" do
      expect(Skylight).to receive(:instrument)
        .with(category: "view.render.template", title: "Inline template (erb)")
        .and_call_original
      allow(Skylight).to receive(:instrument).and_call_original

      get "/inline-template"

      expect(@current_trace.endpoint).to eq("GET /inline-template")
    end
  end
end
