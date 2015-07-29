require 'spec_helper'
require 'skylight/instrumenter'

if defined?(Grape)
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
      expect(Skylight).to receive(:instrument)
                            .with(category: "app.grape.endpoint", title: "GET test")
                            .and_call_original

      get "/test"
    end

    it "instuments mounted apps" do
      expect(Skylight).to receive(:instrument)
                            .with(category: "app.grape.endpoint", title: "GET test")
                            .and_call_original

      get "/app/test"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] test")
    end

    it "instruments more complex endpoints" do
      expect(Skylight).to receive(:instrument)
                            .with(category: "app.grape.endpoint", title: "POST update/:id")
                            .and_call_original

      post "/app/update/1"

      expect(@called_endpoint).to eq("GrapeTest::App [POST] update/:id")
    end

    it "instruments namespaced endpoints" do
      expect(Skylight).to receive(:instrument)
                            .with(category: "app.grape.endpoint", title: "GET users list")
                            .and_call_original

      get "/app/users/list"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] users/list")
    end

    it "instruments wildcard routes" do
      expect(Skylight).to receive(:instrument)
                            .with(category: "app.grape.endpoint", title: "any *path")
                            .and_call_original

      delete "/app/missing"

      expect(@called_endpoint).to eq("GrapeTest::App [any] *path")
    end

    it "instruments failures" do
      expect(Skylight).to receive(:instrument)
                            .with(category: "app.grape.endpoint", title: "GET raise")
                            .and_call_original

      expect{
        get "/raise"
      }.to raise_error("Unexpected error")

      expect(@called_endpoint).to eq("GrapeTest [GET] raise")
    end

    it "instruments filters" do
      expect(Skylight).to receive(:instrument)
                            .ordered
                            .with(category: "app.grape.filters", title: "Before Filters")
                            .and_call_original

      expect(Skylight).to receive(:instrument)
                            .ordered
                            .with("verifying admin")
                            .and_call_original

      expect(Skylight).to receive(:instrument)
                            .ordered
                            .with(category: "app.grape.endpoint", title: "GET admin secret")
                            .and_call_original

      get "/app/admin/secret"

      expect(@called_endpoint).to eq("GrapeTest::App [GET] admin/secret")
    end

    it "handles detailed descriptions"

    # This happens when a path matches but the method does not
    it "treats 405s correctly"
  end
end
