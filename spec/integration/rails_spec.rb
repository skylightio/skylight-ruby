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
  IS_RAILS_4_1_PLUS = Gem::Version.new(Rails.version) >= Gem::Version.new('4.1');
  HAS_MOUNTABLE_ENGINES = Gem::Version.new(Rails.version) >= Gem::Version.new('3.1')

  TEST_VARIANTS = IS_RAILS_4_1_PLUS
  if !TEST_VARIANTS
    puts "[INFO] Skipping Rails format variants test. Must be at least Rails 4.1."
  end

  describe 'Rails integration' do

    def boot
      MyApp.initialize!

      if HAS_MOUNTABLE_ENGINES
        EngineNamespace::MyEngine.routes.draw do
          root :to => lambda { |env| [204, {}, []] }
          get '/empty', :to => lambda { |env| [204, {}, []] }, :as => :empty
          get '/error_from_router', :to => lambda { |env| raise RuntimeError, 'cannot even' }
          get '/error_from_controller', :to => 'application#error'
          get '/show', :to => 'application#show'
        end
      end

      MyApp.routes.draw do
        resources :users do
          collection do
            get :failure
            get :handled_failure
            get :header
            get :status
            get :no_template
            get :throw_something
          end
        end
        get '/metal' => 'metal#show'
        if HAS_MOUNTABLE_ENGINES
          mount EngineNamespace::MyEngine => '/engine'
        end
      end
    end

    before :each do
      @original_env = ENV.to_hash
      ENV['SKYLIGHT_AUTHENTICATION']       = "lulz"
      ENV['SKYLIGHT_BATCH_FLUSH_INTERVAL'] = "1"
      ENV['SKYLIGHT_REPORT_URL']           = "http://127.0.0.1:#{port}/report"
      ENV['SKYLIGHT_REPORT_HTTP_DEFLATE']  = "false"
      ENV['SKYLIGHT_AUTH_URL']             = "http://127.0.0.1:#{port}/agent"
      ENV['SKYLIGHT_VALIDATION_URL']       = "http://127.0.0.1:#{port}/agent/config"
      ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = "false"
      ENV['SKYLIGHT_ENABLE_SEGMENTS']      = "true"

      if ENV['DEBUG']
        ENV['SKYLIGHT_ENABLE_TRACE_LOGS']    = "true"
        ENV['SKYLIGHT_LOG_FILE']             = "-"
      end

      class MiddlewareError < StandardError
      end

      CustomMiddleware ||= Struct.new(:app) do
        def call(env)
          if env["PATH_INFO"] == "/middleware"
            return [200, { }, ["CustomMiddleware"]]
          end

          app.call(env)
        end
      end

      NonClosingMiddleware ||= Struct.new(:app) do
        def call(env)
          res = app.call(env)

          # NOTE: We are intentionally throwing away the response without calling close
          # This is to emulate a non-conforming Middleware
          if env["PATH_INFO"] == "/non-closing"
            return [200, { }, ["NonClosing"]]
          end

          res
        end
      end

      NonArrayMiddleware ||= Struct.new(:app) do
        def call(env)
          if env["PATH_INFO"] == "/non-array"
            # NOTE: This requires Rack 1.3+ for `to_ary`
            return Rack::Response.new(["NonArray"])
          end

          app.call(env)
        end
      end

      InvalidMiddleware ||= Struct.new(:app) do
        def call(env)
          if env["PATH_INFO"] == "/invalid"
            return "Hello"
          end

          app.call(env)
        end
      end

      AssertDeferrals ||= Struct.new(:app) do
        def call(env)
          app.call(env)
        ensure
          assertion_hook
        end

        def assertion_hook
          # override in rspec
        end
      end

      RescuingMiddleware ||= Struct.new(:app) do
        def call(env)
          app.call(env)
        rescue MiddlewareError => e
          [500, {}, ["error=#{e.class.inspect} msg=#{e.to_s.inspect}"]]
        end
      end

      CatchingMiddleware ||= Struct.new(:app) do
        def call(env)
          catch(:coconut) { app.call(env) }
        end
      end

      MonkeyInTheMiddleware ||= Struct.new(:app) do
        # Doesn't do anything on its own; it's here just to play
        # with ThrowingMiddleware and CatchingMiddleware
        delegate :call, to: :app
      end

      ThrowingMiddleware ||= Struct.new(:app) do
        def call(env)
          throw(:coconut, [401, {}, ['I can\'t do that, Dave']]) if should_throw?(env)
          raise MiddlewareError.new('I can\'t do that, Dave') if should_raise?(env)
          app.call(env)
        end

        private

        def should_throw?(env)
          query_parameters(env)[:middleware_throws] == 'true'
        end

        def should_raise?(env)
          query_parameters(env)[:middleware_raises] == 'true'
        end

        def query_parameters(env)
          ActionDispatch::Request.new(env).query_parameters
        end
      end

      module EngineNamespace
        require 'active_record'

        class MyEngine < ::Rails::Engine
          if HAS_MOUNTABLE_ENGINES
            isolate_namespace EngineNamespace
          end
        end

        class ApplicationController < ActionController::Base
          def error
            raise ::ActiveRecord::RecordNotFound
          end

          def show
            render json: {}
          end
        end
      end

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
        config.logger.progname = "Rails"

        config.eager_load = false

        # This class has no name
        config.middleware.use(Class.new do
          def initialize(app)
            @app = app
          end

          def call(env)
            if env["PATH_INFO"] == "/anonymous"
              return [200, { }, ["Anonymous"]]
            end

            @app.call(env)
          end
        end)

        config.middleware.use NonClosingMiddleware
        config.middleware.use NonArrayMiddleware
        config.middleware.use InvalidMiddleware
        config.middleware.use CustomMiddleware
        config.middleware.use AssertDeferrals
        config.middleware.use RescuingMiddleware
        config.middleware.use CatchingMiddleware
        config.middleware.use MonkeyInTheMiddleware
        config.middleware.use ThrowingMiddleware
      end

      # We include instrument_method in multiple places to ensure
      # that all of them work.

      class ::UsersController < ActionController::Base
        include Skylight::Helpers

        class Error < StandardError; end

        if respond_to?(:before_action)
          before_action :authorized?
          before_action :set_variant
        else
          before_filter :authorized?
          before_filter :set_variant
        end

        rescue_from 'Error' do |exception|
          render json: { error: exception.message }, status: 500
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

        def failure
          raise "Fail!"
        end

        def handled_failure
          raise Error, "Handled!"
        end

        def header
          Skylight.instrument category: 'app.zomg' do
            head 200
          end
        end

        def status
          s = params[:status] || 200
          if Rails.version =~ /^(3|4)\./
            render text: s, status: s
          else
            render plain: s, status: s
          end
        end

        def no_template
          # This action has no template to auto-render
        end

        def throw_something
          throw(:coconut, [401, {}, ['I can\'t do that, Dave']])
        end

        private

          def authorized?
            true
          end

          # It's important for us to test a method ending in a special char
          instrument_method :authorized?, title: "Check authorization"

          def set_variant
            request.variant = :tablet if params[:tablet]
          end

      end

      class ::MetalController < ActionController::Metal
        # Ensure ActiveSupport::Notifications events are fired
        if Rails.version =~ /^3\./
          include ActionController::RackDelegation
        end

        include ActionController::Instrumentation

        def show
          render({
            status: 200,
            text: "Zomg!"
          })
        end

        def render(options={})
          self.status = options[:status] || 200
          self.content_type = options[:content_type] || 'text/html; charset=utf-8'
          self.headers['Content-Length'] = options[:text].bytesize.to_s
          self.response_body = options[:text]
        end
      end
    end

    after :each do
      MyApp.config.skylight.middleware_position = 0

      ENV.replace(@original_env)

      Skylight.stop!


      # Clean slate
      # It's really too bad we can't run RSpec tests in a fork
      Object.send(:remove_const, :MyApp)
      Object.send(:remove_const, :EngineNamespace)
      Object.send(:remove_const, :UsersController)
      Object.send(:remove_const, :MetalController)
      if Rails.version =~ /^3.0/
        Rails::Application.class_variable_set(:@@instance, nil)
        ActionController::Routing.send(:remove_const, :Routes)
      end
      Rails::Railtie::Configuration.class_variable_set(:@@app_middleware, nil)
      Rails.application = nil
    end

    let(:router_name) { 'ActionDispatch::Routing::RouteSet' }

    shared_examples "with agent" do

      context "configuration" do

        it "sets log file" do
          expect(Skylight::Instrumenter.instance.config['log_file']).to eq(MyApp.root.join('log/skylight.log').to_s)
        end

        context "on heroku" do

          def pre_boot
            ENV['SKYLIGHT_HEROKU_DYNO_INFO_PATH'] = File.expand_path('../../support/heroku_dyno_info_sample', __FILE__)
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

        segment = Rails.version =~ /^[34]\./ ? 'html' : 'text'
        expect(endpoint.name).to eq("UsersController#index<sk-segment>#{segment}</sk-segment>")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        app_spans = trace.filtered_spans.map{|s| [s.event.category, s.event.title] }.select{|s| s[0] =~ /^app./ }
        expect(app_spans).to eq([
          ["app.rack.request", nil],
          ["app.controller.request", "UsersController#index"],
          ["app.method", "Check authorization"],
          ["app.method", "UsersController#index"],
          ["app.inside", nil],
          ["app.zomg", nil]
        ])
      end

      it 'successfully instruments middleware', :middleware_probe do
        call MyApp, env('/users')
        server.wait resource: '/report'

        trace = server.reports[0].endpoints[0].traces[0]

        app_and_rack_spans = trace.filtered_spans.map{|s| [s.event.category, s.event.title] }.select{|s| s[0] =~ /^(app|rack)./ }

        # We know the first one
        expect(app_and_rack_spans[0]).to eq(["app.rack.request", nil])

        # But the middlewares will be variable, depending on the Rails version
        count = 0
        while true do
          break if app_and_rack_spans[count+1][0] != "rack.middleware"
          count += 1
        end

        # We should have at least 2, but in reality a lot more
        expect(count).to be > 2

        # This one should be in all versions
        expect(app_and_rack_spans).to include(["rack.middleware", "Anonymous Middleware"], ["rack.middleware", "CustomMiddleware"])

        # Check the rest
        expect(app_and_rack_spans[(count+1)..-1]).to eq([
          ["rack.app", router_name],
          ["app.controller.request", "UsersController#index"],
          ["app.method", "Check authorization"],
          ["app.method", "UsersController#index"],
          ["app.inside", nil],
          ["app.zomg", nil]
        ])
      end

      it 'successfully names requests handled by middleware', :middleware_probe do
        res = call MyApp, env('/middleware')
        expect(res).to eq(["CustomMiddleware"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("CustomMiddleware")
      end

      it 'successfully names requests handled by anonymous middleware', :middleware_probe do
        res = call MyApp, env('/anonymous')
        expect(res).to eq(["Anonymous"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("Anonymous Middleware")
      end

      context "with middleware_position" do

        def pre_boot
          MyApp.config.skylight.middleware_position = { after: CustomMiddleware }
        end

        it 'does not instrument middleware if Skylight position is after', :middleware_probe do
          call MyApp, env('/users')
          server.wait resource: '/report'

          trace = server.reports[0].endpoints[0].traces[0]

          titles = trace.filtered_spans.map{ |s| s.event.title }

          # If Skylight runs after CustomMiddleware, we shouldn't see it
          expect(titles).to_not include("CustomMiddleware")
        end

      end

      context "middleware that don't conform to Rack SPEC", middleware: true do

        it "doesn't report middleware that don't close body", :middleware_probe do
          ENV['SKYLIGHT_RAISE_ON_ERROR'] = nil

          expect_any_instance_of(Skylight::Instrumenter).to_not receive(:process)

          call MyApp, env('/non-closing')
        end

        # Rack::Response doesn't have to_ary until 1.3
        if Gem::Version.new(Rack.release) >= Gem::Version.new("1.3")
          it "handles middleware that returns a non-array that is coercable", :middleware_probe do
            ENV['SKYLIGHT_RAISE_ON_ERROR'] = nil

            call MyApp, env('/non-array')
            server.wait resource: '/report'

            trace = server.reports[0].endpoints[0].traces[0]

            titles = trace.filtered_spans.map{ |s| s.event.title }

            expect(titles).to include("NonArrayMiddleware")
          end
        end

      end

      context 'middleware that jumps the stack' do
        it 'closes jumped spans', :middleware_probe do
          allow_any_instance_of(AssertDeferrals).to receive(:assertion_hook) do
            expect(Skylight.trace.send(:deferred_spans)).not_to be_empty
          end
          res = call(MyApp, env('/foo?middleware_throws=true'))
          server.wait(resource: '/report')
          batch = server.reports[0]
          expect(batch).to be_present
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq('ThrowingMiddleware')
          trace = endpoint.traces[0]
          reverse_spans = trace.filtered_spans.reverse_each.map { |span| span.event.title }
          last, middle, catcher = reverse_spans
          expect(last).to eq('ThrowingMiddleware')
          expect(middle).to eq('MonkeyInTheMiddleware')
          expect(catcher).to eq('CatchingMiddleware')
        end

        it 'closes spans over rescue blocks', :middleware_probe do
          # By the time the call stack has finished with this middleware, deferrals
          # should be empty. The rescue block in Probes::Middleware#call
          # should mark those spans done without needing to defer them.
          allow_any_instance_of(AssertDeferrals).to receive(:assertion_hook) do
            expect(Skylight.trace.send(:deferred_spans)).to eq({})
          end
          res = call(MyApp, env('/foo?middleware_raises=true'))
          server.wait(resource: '/report')
          batch = server.reports[0]
          expect(batch).to be_present
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq('ThrowingMiddleware')
          trace = endpoint.traces[0]
          reverse_spans = trace.filtered_spans.reverse_each.map { |span| span.event.title }
          last, middle, catcher, rescuer = reverse_spans
          expect(last).to eq('ThrowingMiddleware')
          expect(middle).to eq('MonkeyInTheMiddleware')
          expect(catcher).to eq('CatchingMiddleware')
          expect(rescuer).to eq('RescuingMiddleware')
        end

        it 'closes spans jumped in the controller', :middleware_probe do
          allow_any_instance_of(AssertDeferrals).to receive(:assertion_hook) do
            expect(Skylight.trace.send(:deferred_spans)).not_to be_empty
          end
          res = call(MyApp, env('/users/throw_something'))
          server.wait(resource: '/report')
          batch = server.reports[0]
          expect(batch).to be_present
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq('UsersController#throw_something')
          trace = endpoint.traces[0]
          reverse_spans = trace.filtered_spans.reverse_each.map do |span|
            [span.event.category, span.event.title]
          end

          # it closes all spans between the throw and the catch
          expect(reverse_spans.take(6)).to eq([
            ["app.method", "Check authorization"],
            ["app.controller.request", "UsersController#throw_something"],
            ["rack.app", router_name],
            ["rack.middleware", "ThrowingMiddleware"],
            ["rack.middleware", "MonkeyInTheMiddleware"],
            ["rack.middleware", "CatchingMiddleware"]
          ])
        end
      end

      it 'sets correct segment' do
        res = call MyApp, env('/users/1.json')
        expect(res).to eq([{ hola: '1' }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#show<sk-segment>json</sk-segment>")
      end

      it 'sets rendered segment, not requested' do
        res = call MyApp, env('/users/1', 'HTTP_ACCEPT' => '*/*')
        expect(res).to eq([{ hola: '1' }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#show<sk-segment>json</sk-segment>")
      end

      it 'sets correct segment for exceptions' do
        # Turn off for this test, since it will log a ton, due to the mock
        ENV['SKYLIGHT_RAISE_ON_ERROR'] = nil

        res = call MyApp, env('/users/failure')
        if Rails.version =~ /^3\.0/
          expect(res).to eq([""])
        else
          expect(res).to be_empty
        end

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#failure<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment for handled exceptions' do
        status, headers, body = call_full MyApp, env('/users/handled_failure')
        expect(status).to eq(500)
        expect(body).to eq([{ error: "Handled!" }.to_json])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        expect(endpoint.name).to eq("UsersController#handled_failure<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment for `head`' do
        status, headers, body = call_full MyApp, env('/users/header')
        expect(status).to eq(200)
        expect(body[0].strip).to eq('') # Some Rails versions have a space, some don't

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]

        if IS_RAILS_4_1_PLUS
          expect(endpoint.name).to eq("UsersController#header")
        else
          expect(endpoint.name).to eq("UsersController#header<sk-segment>html</sk-segment>")
        end

        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]
        names = trace.filtered_spans.map { |s| s.event.category }

        expect(names.length).to be >= 3
        expect(names).to include('app.zomg')
        expect(names[0]).to eq('app.rack.request')
      end

      it 'sets correct segment for 4xx responses' do
        status, headers, body = call_full MyApp, env('/users/status?status=404')
        expect(status).to eq(404)
        expect(body).to eq(['404'])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#status<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment for 5xx responses' do
        status, headers, body = call_full MyApp, env('/users/status?status=500')
        expect(status).to eq(500)
        expect(body).to eq(['500'])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#status<sk-segment>error</sk-segment>")
      end

      it 'sets correct segment when no template is found' do
        status, headers, body = call_full MyApp, env('/users/no_template')

        if Rails.version =~ /^[34]\./
          expect(status).to eq(500)
        else
          expect(status).to eq(406)
        end

        expect(body[0]).to be_blank

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("UsersController#no_template<sk-segment>error</sk-segment>")
      end

      if HAS_MOUNTABLE_ENGINES
        it 'sets correct segment for router-handled requests', engine: true do
          res = call MyApp, env('/engine/empty')
          expect(res).to eq([])
          server.wait resource: '/report'
          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq(router_name)
        end

        it 'sets correct segment for an engine', engine: true do
          res = call MyApp, env('/engine/error_from_router')
          expect(res).to eq([])
          server.wait(resource: '/report')
          endpoint = server.reports[0].endpoints[0]
          expect(endpoint.name).to eq(router_name)
          trace = endpoint.traces.first
          spans = trace.filtered_spans
          # Should include the routers from both the main app and the engine
          expect(spans.last(2).map { |s| s.event.title }).to eq([router_name, router_name])
        end

        it 'forwards exceptions in the engine to the main app', engine: true do
          res = call MyApp, env('/engine/error_from_controller')
          server.wait(resource: '/report')
          endpoint = server.reports[0].endpoints[0]
          endpoint_name = 'EngineNamespace::ApplicationController#error'
          expect(endpoint.name).to eq("#{endpoint_name}<sk-segment>error</sk-segment>")
          trace = endpoint.traces.first
          spans = trace.filtered_spans.last(3)
          # Should include the routers from both the main app and the engine
          expect(spans.map { |s| s.event.title }).to eq([router_name, router_name, endpoint_name])
        end

        it 'handles routing errors', engine: true do
          expect {
            res = call MyApp, env('/engine/foo/bar/bin')
          }.not_to raise_error
          server.wait(resource: '/report')
          endpoint = server.reports[0].endpoints[0]
          expect(endpoint.name).to eq(router_name)
          trace = endpoint.traces.first
          spans = trace.filtered_spans.last(2)
          # Should include the routers from both the main app and the engine
          expect(spans.map { |s| s.event.title }).to eq([router_name, router_name])
        end
      end

      if TEST_VARIANTS
        it 'sets correct segment with variant' do
          res = call MyApp, env('/users/1.json?tablet=1')
          expect(res).to eq([{ hola_tablet: '1' }.to_json])

          server.wait resource: '/report'

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq("UsersController#show<sk-segment>json+tablet</sk-segment>")
        end

        it 'sets correct segment for `head` with variant' do
          status, headers, body = call_full MyApp, env('/users/header?tablet=1', 'HTTP_ACCEPT' => 'application/json')
          expect(status).to eq(200)
          expect(body[0].strip).to eq('') # Some Rails versions have a space, some don't

          server.wait resource: '/report'

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]
          expect(endpoint.name).to eq("UsersController#header")
        end
      end

      it 'can instrument metal controllers' do
        call MyApp, env('/metal')

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("MetalController#show<sk-segment>html</sk-segment>")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.filtered_spans.map { |s| s.event.category }

        expect(names.length).to be >= 1
        expect(names[0]).to eq('app.rack.request')
      end

    end

    context "activated from application.rb", :http, :agent do

      def pre_boot
      end

      before :each do
        @original_environments = MyApp.config.skylight.environments.clone
        MyApp.config.skylight.environments << 'development'

        stub_config_validation
        stub_session_request

        pre_boot
        boot
      end

      after :each do
        MyApp.config.skylight.environments = @original_environments
      end

      it_behaves_like 'with agent'
    end

    context "activated from ENV", :http, :agent do

      def pre_boot
      end

      before :each do
        ENV['SKYLIGHT_ENABLED'] = "true"

        stub_config_validation
        stub_session_request

        pre_boot
        boot
      end

      it_behaves_like 'with agent'
    end

    shared_examples "without agent" do

      before :each do
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

    context "without configuration" do
      before :each do
        boot
      end

      it_behaves_like 'without agent'
    end

    context "deactivated from ENV" do
      def pre_boot
      end

      before :each do
        ENV['SKYLIGHT_ENABLED'] = "false"

        @original_environments = MyApp.config.skylight.environments.clone
        MyApp.config.skylight.environments << 'development'

        pre_boot
        boot
      end

      after :each do
        MyApp.config.skylight.environments = @original_environments
      end

      it_behaves_like 'without agent'
    end


    def call_full(app, env)
      resp = app.call(env)
      consume(resp)
      resp
    end

    def call(app, env)
      call_full(app, env)[2]
    end

    def env(path = '/', opts = {})
      Rack::MockRequest.env_for(path, opts)
    end

    def consume(resp)
      data = []
      resp[2].each{|p| data << p }
      resp[2].close
      resp[2] = data
      resp
    end

  end
end
