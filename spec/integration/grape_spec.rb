require "spec_helper"

enable = false
begin
  require "grape"
  require "skylight"
  enable = true
rescue LoadError
  puts "[INFO] Skipping grape integration specs"
end

if enable
  describe "Grape integration" do
    before :each do
      ENV["SKYLIGHT_AUTHENTICATION"] = "lulz"
      ENV["SKYLIGHT_BATCH_FLUSH_INTERVAL"] = "10ms"
      ENV["SKYLIGHT_REPORT_URL"] = "http://127.0.0.1:#{port}/report"
      ENV["SKYLIGHT_REPORT_HTTP_DEFLATE"] = "false"
      ENV["SKYLIGHT_AUTH_URL"] = "http://127.0.0.1:#{port}/agent"
      ENV["SKYLIGHT_VALIDATION_URL"] = "http://127.0.0.1:#{port}/agent/config"
      ENV["SKYLIGHT_AUTH_HTTP_DEFLATE"] = "false"

      Skylight.start!

      stub_const(
        "DUMMY_ROUTE",
        lambda do |path: :test|
          get path do
            Skylight.instrument category: category do
              Skylight.instrument category: "app.zomg" do
                # nothing
              end
            end

            { hello: true }
          end
        end
      )

      stub_const(
        "MySubApp",
        Class.new(Grape::API) do
          helpers do
            def category
              "app.sub"
            end
          end

          namespace :sub_ns do
            instance_exec(&::DUMMY_ROUTE)
          end

          # intentional path conflict. Overloads 'test' in the main app
          instance_exec(&::DUMMY_ROUTE)
        end
      )

      stub_const(
        "MyInheritedApp",
        Class.new(::MySubApp) do
          namespace :inherited_ns do
            instance_exec(&::DUMMY_ROUTE)
          end
        end
      )

      stub_const(
        "MyApp",
        Class.new(Grape::API) do
          use Skylight::Middleware

          helpers do
            def category
              "app.inside"
            end
          end

          instance_exec(&::DUMMY_ROUTE)

          namespace :ns do
            instance_exec(&::DUMMY_ROUTE)
          end

          mount ::MySubApp

          namespace :inherited do
            helpers do
              def category
                super << ".inherited"
              end
            end

            mount ::MyInheritedApp
          end
        end
      )

      paths = MyApp.routes.map(&:path)

      # sanity check
      expect(paths.sort).to eq(
        [
          # main app
          "/test(.:format)",
          "/ns/test(.:format)",
          # sub app
          "/sub_ns/test(.:format)",
          "/test(.:format)",
          "/inherited/inherited_ns/test(.:format)"
        ].sort
      )
    end

    after :each do
      ENV["SKYLIGHT_AUTHENTICATION"] = nil
      ENV["SKYLIGHT_BATCH_FLUSH_INTERVAL"] = nil
      ENV["SKYLIGHT_REPORT_URL"] = nil
      ENV["SKYLIGHT_REPORT_HTTP_DEFLATE"] = nil
      ENV["SKYLIGHT_AUTH_URL"] = nil
      ENV["SKYLIGHT_VALIDATION_URL"] = nil
      ENV["SKYLIGHT_AUTH_HTTP_DEFLATE"] = nil

      Skylight.stop!
    end

    let :app do
      Rack::Builder.new { run MyApp }
    end

    context "with agent", :http, :agent do
      before :each do
        stub_config_validation
        stub_session_request
      end

      shared_examples_for :grape_instrumentation do
        it "successfully calls into grape" do
          res = call env(request_path)
          expect(res).to eq(["{:hello=>true}"])

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq(expected_endpoint_name)
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          names = trace.filter_spans.map { |s| s.event.category }

          expect(names.length).to be >= 3
          expect(names).to include("app.zomg")
          expect(names).to include(expected_category)
          expect(names[0]).to eq("app.rack.request")

          expect(names.last).to eq("view.grape.format_response") if ENV["GRAPE_VERSION"] == "edge"
        end
      end

      it_behaves_like :grape_instrumentation do
        let(:request_path) { "/test/?foo=bar" }
        let(:expected_endpoint_name) { "MyApp [GET] test" }
        let(:expected_category) { "app.inside" }
      end

      it_behaves_like :grape_instrumentation do
        let(:request_path) { "/inherited/inherited_ns/test//?foo=bar" }
        let(:expected_endpoint_name) { "MyInheritedApp [GET] inherited/inherited_ns/test" }
        let(:expected_category) { "app.inside.inherited" }
      end

      it_behaves_like :grape_instrumentation do
        let(:request_path) { "/sub_ns/test/\/?foo=bar" }
        let(:expected_endpoint_name) { "MySubApp [GET] sub_ns/test" }
        let(:expected_category) { "app.sub" }
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
      resp[2].to_a
    ensure
      resp[2].close
    end
  end
end
