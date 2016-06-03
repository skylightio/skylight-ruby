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

  TEST_VARIANTS = Gem::Version.new(Rails.version) >= Gem::Version.new('4.1');
  if !TEST_VARIANTS
    puts "[INFO] Skipping Rails format variants test. Must be at least Rails 4.1."
  end

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
      ENV['SKYLIGHT_SEPARATE_FORMATS']     = "true"

      class ::MyApp < Rails::Application
        if Rails.version =~ /^3\./
          config.secret_token = '095f674153982a9ce59914b561f4522a'
        else
          config.secret_key_base = '095f674153982a9ce59914b561f4522a'
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

        if respond_to?(:before_action)
          before_action :authorized?
        else
          before_filter :authorized?
        end

        def index
          Skylight.instrument category: 'app.inside' do
            if Rails.version =~ /^(3|4)\./
              render text: "Hello"
            else
              render plain: "Hello"
            end
            Skylight.instrument category: 'app.zomg' do
              # nothing
            end
          end
        end
        instrument_method :index

        instrument_method
        def show
          request.variant = :tablet if params[:tablet]

          respond_to do |format|
            format.json do |json|
              if TEST_VARIANTS
                json.tablet { render json: { hola_tablet: params[:id] } }
                json.none   { render json: { hola: params[:id] } }
              else
                render json: { hola: params[:id] }
              end
            end
            format.html do
              if Rails.version =~ /^(3|4)\./
                render text: "Hola: #{params[:id]}"
              else
                render plain: "Hola: #{params[:id]}"
              end
            end
          end
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
          if Rails.version =~ /^(3|4)\./
            render text: "Zomg!"
          else
            render plain: "Zomg!"
          end
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
      ENV['SKYLIGHT_SEPARATE_FORMATS']     = nil

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

      def pre_boot
      end

      before :each do
        @original_environments = MyApp.config.skylight.environments.clone
        MyApp.config.skylight.environments << 'development'

        stub_token_verification
        stub_session_request

        pre_boot
        boot
      end

      after :each do
        MyApp.config.skylight.environments = @original_environments
      end

      context "configuration" do

        it "sets log file" do
          expect(Skylight::Instrumenter.instance.config['log_file']).to eq(MyApp.root.join('log/skylight.log').to_s)
        end

        context "on heroku" do

          def pre_boot
            ENV['SKYLIGHT_HEROKU_DYNO_INFO_PATH'] = File.expand_path('../../support/heroku_dyno_info_sample', __FILE__)
          end

          after :each do
            ENV['SKYLIGHT_HEROKU_DYNO_INFO_PATH'] = nil
          end

          it "recognizes heroku" do
            expect(Skylight::Instrumenter.instance.config).to be_on_heroku
          end

          it "leaves log file as STDOUT" do
            expect(Skylight::Instrumenter.instance.config['log_file']).to eq('-')
          end

        end

      end

      it 'successfully calls into rails' do
        res = call MyApp, env('/users')
        expect(res).to eq(["Hello"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#index<sk-format>html</sk-format>")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.spans.map { |s| s.event.category }

        expect(names.length).to be >= 3
        expect(names).to include('app.zomg')
        expect(names).to include('app.inside')
        expect(names[0]).to eq('app.rack.request')
      end

      it 'sets correct format' do
        res = call MyApp, env('/users/1.json')
        expect(res).to eq([{ hola: '1' }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#show<sk-format>json</sk-format>")
      end

      if TEST_VARIANTS
        it 'sets correct format with variant' do
          res = call MyApp, env('/users/1.json?tablet=1')
          expect(res).to eq([{ hola_tablet: '1' }.to_json])

          server.wait resource: '/report'

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq("UsersController#show<sk-format>json+tablet</sk-format>")
        end
      end

      it 'can instrument metal controllers' do
        call MyApp, env('/metal')

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("MetalController#show<sk-format>html</sk-format>")
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
      Rack::MockRequest.env_for(path, opts)
    end

    def consume(resp)
      data = []
      resp[2].each{|p| data << p }
      resp[2].close
      data
    end

  end
end
