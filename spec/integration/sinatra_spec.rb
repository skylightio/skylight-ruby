require "spec_helper"
require "skylight/instrumenter"

enable = false
begin
  require "sinatra"
  require "skylight/sinatra"
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sinatra integration specs"
end

if enable
  describe "Sinatra integration" do
    before :each do
      @original_env = ENV.to_hash
      set_agent_env

      Skylight.start!

      class ::MyApp < ::Sinatra::Base
        get "/test" do
          Skylight.instrument category: "app.inside" do
            Skylight.instrument category: "app.zomg" do
              # nothing
            end
            erb "Hello"
          end
        end
      end
    end

    after :each do
      ENV.replace(@original_env)

      Skylight.stop!

      # Clean slate
      Object.send(:remove_const, :MyApp)
    end

    let :app do
      Rack::URLMap.new(
        "/"               => MyApp,
        "/url_prefix/api" => MyApp
      )
    end

    context "with agent", :http, :agent do
      before :each do
        stub_config_validation
        stub_session_request
      end

      shared_examples_for :sinatra do
        it "successfully calls into sinatra" do
          res = call env(req_path)
          expect(res).to eq(["Hello"])

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq(endpoint_name)
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          names = trace.spans.map { |s| s.event.category }

          expect(names.length).to be >= 3
          expect(names).to include("app.zomg")
          expect(names).to include("app.inside")
          expect(names[0]).to eq("app.rack.request")
        end
      end

      it_behaves_like :sinatra do
        let(:req_path) { "/test" }
        let(:endpoint_name) { "GET /test" }
      end

      context "url prefixes disabled" do
        it_behaves_like :sinatra do
          let(:req_path) { "/url_prefix/api/test" }
          let(:endpoint_name) { "GET /test" }
        end
      end

      context "url prefixes enabled" do
        def set_agent_env
          super
          ENV["SKYLIGHT_SINATRA_ROUTE_PREFIXES"] = "true"
        end

        it_behaves_like :sinatra do
          let(:req_path) { "/url_prefix/api/test" }
          let(:endpoint_name) { "GET [/url_prefix/api]/test" }
        end
      end
    end

    def call(env)
      resp = app.call(env)
      consume(resp)
    end

    def env(path = "/", opts = {})
      Rack::MockRequest.env_for(path, opts)
    end

    def consume(resp)
      data = []
      resp[2].each { |p| data << p }
      resp[2].close if resp[2].respond_to?(:close)
      data
    end
  end
end
