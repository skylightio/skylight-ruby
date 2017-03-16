require 'spec_helper'
require 'skylight/instrumenter'

if defined?(Grape)
  # FIXME: We should also add unit specs for the grape normalizers
  describe 'Grape integration', :grape_probe, :agent do
    include Rack::Test::Methods

    before do
      @called_endpoint = nil
      Skylight::Instrumenter.mock! do |trace|
        @called_endpoint = trace.endpoint
      end
    end

    after do
      Skylight::Instrumenter.stop!
    end

    class GrapeTest < Grape::API
      class App < Grape::API
        get "test" do
          { test: true }
        end

        desc 'Update item' do
          detail 'We take the id to update the item'
          named 'Update route'
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
          before do
            Skylight.instrument("verifying admin")
          end

          get :secret do
            { admin: true }
          end
        end

        route :any, "*path" do
          { path: params[:path] }
        end
      end

      format :json

      mount App => '/app'

      desc 'This is a test'
      get "test" do
        { test: true }
      end

      get "raise" do
        fail 'Unexpected error'
      end

      route ['GET', 'POST'], "data" do
        "data"
      end
    end

    def app
      Rack::Builder.new do
        use Skylight::Middleware
        run GrapeTest
      end
    end

    it "creates a Trace for a Grape app" do
      expect(Skylight).to receive(:trace).with("Rack", "app.rack.request").and_call_original

      get "/test"

      expect(@called_endpoint).to eq("GrapeTest [GET] test")
      expect(JSON.parse(last_response.body)).to eq("test" => true)
    end

    it "instruments the endpoint body" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "GET test", nil)
          .once

      get "/test"
    end

    it "instruments mounted apps" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "GET test", nil)
          .once

      get "/app/test"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] test")
    end

    it "instruments more complex endpoints" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "POST update/:id", nil)
          .once

      post "/app/update/1"

      expect(@called_endpoint).to eq("GrapeTest::App [POST] update/:id")
    end

    it "instruments namespaced endpoints" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "GET users list", nil)
          .once

      get "/app/users/list"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] users/list")
    end

    it "instruments wildcard routes" do
      wildcard = Gem::Version.new(Grape::VERSION) >= Gem::Version.new("0.19") ? "*" : "any"

      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "#{wildcard} *path", nil)
          .once

      delete "/app/missing"

      expect(@called_endpoint).to eq("GrapeTest::App [#{wildcard}] *path")
    end

    it "instruments multi method routes" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "GET... data", nil)
          .once

      get "/data"

      expect(@called_endpoint).to eq("GrapeTest [GET...] data")
    end

    it "instruments failures" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "GET raise", nil)
          .once

      expect{
        get "/raise"
      }.to raise_error("Unexpected error")

      expect(@called_endpoint).to eq("GrapeTest [GET] raise")
    end

    it "instruments filters" do
      allow_any_instance_of(Skylight::Trace).to receive(:instrument)

      # TODO: Attempt to verify order
      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.filters", "Before Filters", nil)
          .once

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.block", "verifying admin", nil)
          .once

      expect_any_instance_of(Skylight::Trace).to receive(:instrument)
          .with("app.grape.endpoint", "GET admin secret", nil)
          .once

      get "/app/admin/secret"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] admin/secret")
    end

    it "handles detailed descriptions"

    # This happens when a path matches but the method does not
    it "treats 405s correctly"
  end
end
