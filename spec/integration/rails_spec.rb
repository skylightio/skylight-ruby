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

  class MyApp < Rails::Application
    if Rails.version =~ /^4\./
      config.secret_key_base = '095f674153982a9ce59914b561f4522a'
    else
      config.secret_token = '095f674153982a9ce59914b561f4522a'
    end

    config.active_support.deprecation = :stderr

    config.skylight.environments << 'development'

    config.logger = Logger.new(STDOUT)
    config.logger.level = Logger::DEBUG
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

  describe 'Rails integration' do

    before :all do
      ENV['SKYLIGHT_AUTHENTICATION']      = 'lulz'
      ENV['SKYLIGHT_AGENT_INTERVAL']      = '1'
      ENV['SKYLIGHT_AGENT_STRATEGY']      = 'embedded'
      ENV['SKYLIGHT_REPORT_HOST']         = 'localhost'
      ENV['SKYLIGHT_REPORT_PORT']         = port.to_s
      ENV['SKYLIGHT_REPORT_SSL']          = false.to_s
      ENV['SKYLIGHT_REPORT_DEFLATE']      = false.to_s
      ENV['SKYLIGHT_ACCOUNTS_HOST']       = 'localhost'
      ENV['SKYLIGHT_ACCOUNTS_PORT']       = port.to_s
      ENV['SKYLIGHT_ACCOUNTS_SSL']        = false.to_s
      ENV['SKYLIGHT_ACCOUNTS_DEFLATE']    = false.to_s
      ENV['SKYLIGHT_TEST_CONSTANT_FLUSH'] = true.to_s
      ENV['SKYLIGHT_TEST_IGNORE_TOKEN']   = true.to_s

      MyApp.initialize!

      MyApp.routes.draw do
        resources :users
      end
    end

    after :all do
      ENV['SKYLIGHT_AUTHENTICATION']    = nil
      ENV['SKYLIGHT_AGENT_INTERVAL']    = nil
      ENV['SKYLIGHT_AGENT_STRATEGY']    = nil
      ENV['SKYLIGHT_REPORT_HOST']       = nil
      ENV['SKYLIGHT_REPORT_PORT']       = nil
      ENV['SKYLIGHT_REPORT_SSL']        = nil
      ENV['SKYLIGHT_REPORT_DEFLATE']    = nil
      ENV['SKYLIGHT_ACCOUNTS_HOST']     = nil
      ENV['SKYLIGHT_ACCOUNTS_PORT']     = nil
      ENV['SKYLIGHT_ACCOUNTS_SSL']      = nil
      ENV['SKYLIGHT_ACCOUNTS_DEFLATE']  = nil
      ENV['SKYLIGHT_TEST_IGNORE_TOKEN'] = nil

      Skylight.stop!
    end

    after :each do
      # Temporary hax
      if instrumenter = Skylight::Instrumenter.instance
        instrumenter.current_trace = nil
      end
    end

    context "with agent", :http, :agent do

      let :token do
        "hey-guyz-i-am-a-token"
      end

      before :each do
        server.mock "/agent/authenticate" do |env|
          { session: { token: token, expires_at: 3.hours.from_now.to_i } }
        end
      end

      it 'successfully calls into rails' do
        call MyApp, env('/users')

        server.wait count: 2

        batch = server.reports[0]
        batch.should_not be nil
        batch.endpoints.count.should == 1
        endpoint = batch.endpoints[0]
        endpoint.name.should == "UsersController#index"
        endpoint.traces.count.should == 1
        trace = endpoint.traces[0]

        names = trace.spans.map { |s| s.event.category }

        names.length.should be >= 2
        names.should include('app.zomg')
        names.should include('app.inside')
        names[0].should == 'app.rack.request'
      end

    end

    context "without agent" do

      it "allows calls to Skylight.instrument" do
        call(MyApp, env('/users')).should == ["Hello"]
      end

      it "supports Skylight::Helpers" do
        call(MyApp, env('/users/1')).should == ["Hola: 1"]
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
