require "spec_helper"
require "skylight/instrumenter"

begin
  require "grape"
rescue LoadError
  warn "Skipping Grape tests since it isn't installed."
end

if defined?(Grape)
  describe "Grape integration", :agent do
    include Rack::Test::Methods

    before do
      @called_endpoint = nil
      Skylight.mock! { |trace| @called_endpoint = trace.endpoint }

      # Ideally, we'd not define this globally, but trying to use stub_const is causing issues for the specs.
      class GrapeTest < Grape::API # rubocop:disable Lint/ConstantDefinitionInBlock
        class App < Grape::API
          get "test" do
            { test: true }
          end

          desc "Update item" do
            detail "We take the id to update the item"
            named "Update route"
          end
          post "update/:id" do
            { update: true }
          end

          namespace :users do
            get :list do
              { users: [] }
            end
          end

          namespace :admin do
            before { Skylight.instrument("verifying admin") { SpecHelper.clock.skip 1 } }

            get :secret do
              { admin: true }
            end
          end

          route :any, "*path" do
            { path: params[:path] }
          end
        end

        format :json

        mount App => "/app"

        desc "This is a test"
        get "test" do
          { test: true }
        end

        get "raise" do
          raise "Unexpected error"
        end

        route %w[GET POST], "data" do
          "data"
        end
      end
    end

    after do
      Object.send(:remove_const, :GrapeTest)

      Skylight.stop!
    end

    def app
      Rack::Builder.new do
        use Skylight::Middleware
        run GrapeTest
      end
    end

    def expect_endpoint_instrument(title)
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
        .with("app.grape.endpoint", title, nil, hash_including({}))
        .once
    end

    it "creates a Trace for a Grape app" do
      expect(Skylight).to receive(:trace)
        .with("Rack", "app.rack.request", nil, meta: { source_location: Skylight::Trace::SYNTHETIC }, component: :web)
        .and_wrap_original do |method, *args|
        # NOTE: rspec-mocks 3.10 is not fully compatible with Ruby 3. This `and_wrap_original` should
        # be replaced by `and_call_original` in future versions.
        *positional, kwargs = args
        method.call(*positional, **kwargs)
      end

      get "/test"

      expect(@called_endpoint).to eq("GrapeTest [GET] test")
      expect(JSON.parse(last_response.body)).to eq("test" => true)
    end

    it "instruments the endpoint body" do
      expect_endpoint_instrument("GET test")

      get "/test"
    end

    it "instruments mounted apps" do
      expect_endpoint_instrument("GET test")

      get "/app/test"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] test")
    end

    it "instruments more complex endpoints" do
      expect_endpoint_instrument("POST update/:id")

      post "/app/update/1"

      expect(@called_endpoint).to eq("GrapeTest::App [POST] update/:id")
    end

    it "instruments namespaced endpoints" do
      expect_endpoint_instrument("GET users list")

      get "/app/users/list"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] users/list")
    end

    it "instruments wildcard routes" do
      expect_endpoint_instrument("* *path")

      delete "/app/missing"

      expect(@called_endpoint).to eq("GrapeTest::App [*] *path")
    end

    it "instruments multi method routes" do
      expect_endpoint_instrument("GET... data")

      get "/data"

      expect(@called_endpoint).to eq("GrapeTest [GET...] data")
    end

    it "instruments failures" do
      expect_endpoint_instrument("GET raise")

      expect { get "/raise" }.to raise_error("Unexpected error")

      expect(@called_endpoint).to eq("GrapeTest [GET] raise")
    end

    it "instruments filters" do
      expect_endpoint_instrument("GET admin secret")

      # TODO: Attempt to verify order
      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
        .with("app.grape.filters", "Before Filters", nil, an_instance_of(Hash))
        .once

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
        .with("app.block", "verifying admin", nil, an_instance_of(Hash))
        .once

      get "/app/admin/secret"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] admin/secret")
    end

    it "handles detailed descriptions"

    # This happens when a path matches but the method does not
    it "treats 405s correctly"
  end
end
