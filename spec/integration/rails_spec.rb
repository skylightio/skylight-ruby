require 'spec_helper'

enable = false
begin
  require 'rails'
  require 'action_controller/railtie'
  require 'skylight/railtie'
  enable = true
rescue LoadError
  puts "[INFO] Skipping rails integration specs"
end

if enable

  describe 'Rails integration' do

    def boot
      MyApp.initialize!

      MyApp.routes.draw do
        resources :users
        get '/metal' => 'metal#show'
      end
    end

    before :each do
      ENV['SKYLIGHT_AUTHENTICATION']       = "lulz"
      ENV['SKYLIGHT_BATCH_FLUSH_INTERVAL'] = "1"
      ENV['SKYLIGHT_REPORT_URL']           = "http://localhost:#{port}/report"
      ENV['SKYLIGHT_REPORT_HTTP_DEFLATE']  = "false"
      ENV['SKYLIGHT_AUTH_URL']             = "http://localhost:#{port}/agent/authenticate"
      ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = "false"
      # ENV['SKYLIGHT_TEST_IGNORE_TOKEN']   = true.to_s

      class ::MyApp < Rails::Application
        if Rails.version =~ /^4\./
          config.secret_key_base = '095f674153982a9ce59914b561f4522a'
        else
          config.secret_token = '095f674153982a9ce59914b561f4522a'
        end

        if Rails.version =~ /^3/
          # Workaround for initialization issue with 3.2
          config.action_view.stylesheet_expansions = {}
          config.action_view.javascript_expansions = {}
        end

        config.active_support.deprecation = :stderr

        config.logger = Logger.new(STDOUT)
        config.logger.level = Logger::DEBUG

        config.eager_load = false
      end

      # We include instrument_method in multiple places to ensure
      # that all of them work.

      class ::UsersController < ActionController::Base
        include Skylight::Helpers

        before_filter :authorized?

        def index
          Skylight.instrument category: 'app.inside' do
            render text: "Hello"
            Skylight.instrument category: 'app.zomg' do
              # nothing
            end
          end
        end
        instrument_method :index

        instrument_method
        def show
          render text: "Hola: #{params[:id]}"
        end

        private

          def authorized?
            true
          end

          # It's important for us to test a method ending in a special char
          instrument_method :authorized?, title: "Check authorization"
      end

      class ::MetalController < ActionController::Metal
        # Ensure ActiveSupport::Notifications events are fired
        if Rails.version =~ /^3\./
          include ActionController::RackDelegation
        end
        # Weird that we need both Rendering modules
        include AbstractController::Rendering
        include ActionController::Rendering

        include ActionController::Instrumentation

        def show
          render text: "Zomg!"
        end
      end
    end

    after :each do
      ENV['SKYLIGHT_AUTHENTICATION']       = nil
      ENV['SKYLIGHT_BATCH_FLUSH_INTERVAL'] = nil
      ENV['SKYLIGHT_REPORT_URL']           = nil
      ENV['SKYLIGHT_REPORT_HTTP_DEFLATE']  = nil
      ENV['SKYLIGHT_AUTH_URL']             = nil
      ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = nil
      # ENV['SKYLIGHT_TEST_IGNORE_TOKEN']   = nil

      Skylight.stop!

      if Rails.version =~ /^3.0/
        Rails::Application.class_eval do
          @@instance = nil
        end
      end

      # Clean slate
      Object.send(:remove_const, :MyApp)
      Object.send(:remove_const, :UsersController)
      Rails.application = nil
    end

    context "with agent", :http, :agent do

      before :each do
        @original_environments = MyApp.config.skylight.environments.clone
        MyApp.config.skylight.environments << 'development'

        stub_token_verification
        stub_session_request

        boot
      end

      after :each do
        MyApp.config.skylight.environments = @original_environments
      end

      it 'successfully calls into rails' do
        call MyApp, env('/users')

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#index")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.spans.map { |s| s.event.category }

        expect(names.length).to be >= 3
        expect(names).to include('app.zomg')
        expect(names).to include('app.inside')
        expect(names[0]).to eq('app.rack.request')
      end

      it 'can instrument metal controllers' do
        call MyApp, env('/metal')

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("MetalController#show")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.spans.map { |s| s.event.category }

        expect(names.length).to be >= 1
        expect(names[0]).to eq('app.rack.request')
      end

    end

    context "without agent" do

      before :each do
        boot

        # Sanity check that we are indeed running without an active agent
        expect(Skylight::Instrumenter.instance).to be_nil
      end

      it "allows calls to Skylight.instrument" do
        expect(call(MyApp, env('/users'))).to eq(["Hello"])
      end

      it "supports Skylight::Helpers" do
        expect(call(MyApp, env('/users/1'))).to eq(["Hola: 1"])
      end

    end

    def call(app, env)
      resp = app.call(env)
      consume(resp)
    end

    def env(path = '/', opts = {})
      Rack::MockRequest.env_for(path, {})
    end

    def consume(resp)
      data = []
      resp[2].each{|p| data << p }
      resp[2].close
      data
    end

  end
end
