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

  class ::UsersController < ActionController::Base
    def index
      Skylight.instrument category: 'app.inside' do
        render text: "Hello"
        Skylight.instrument category: 'app.zomg' do
          # nothing
        end
      end
    end
  end

  describe 'Rails integration', :http do

    before :all do
      ENV['SKYLIGHT_AUTHENTICATION']   = 'lulz'
      ENV['SKYLIGHT_AGENT_INTERVAL']   = '1'
      ENV['SKYLIGHT_AGENT_STRATEGY']   = 'embedded'
      ENV['SKYLIGHT_REPORT_HOST']      = 'localhost'
      ENV['SKYLIGHT_REPORT_PORT']      = port.to_s
      ENV['SKYLIGHT_REPORT_SSL']       = false.to_s
      ENV['SKYLIGHT_REPORT_DEFLATE']   = false.to_s
      ENV['SKYLIGHT_ACCOUNTS_HOST']    = 'localhost'
      ENV['SKYLIGHT_ACCOUNTS_PORT']    = port.to_s
      ENV['SKYLIGHT_ACCOUNTS_SSL']     = false.to_s
      ENV['SKYLIGHT_ACCOUNTS_DEFLATE'] = false.to_s

      MyApp.initialize!

      MyApp.routes.draw do
        resources :users
      end
    end

    after :all do
      ENV['SKYLIGHT_AUTHENTICATION']   = nil
      ENV['SKYLIGHT_AGENT_INTERVAL']   = nil
      ENV['SKYLIGHT_AGENT_STRATEGY']   = nil
      ENV['SKYLIGHT_REPORT_HOST']      = nil
      ENV['SKYLIGHT_REPORT_PORT']      = nil
      ENV['SKYLIGHT_REPORT_SSL']       = nil
      ENV['SKYLIGHT_REPORT_DEFLATE']   = nil
      ENV['SKYLIGHT_ACCOUNTS_HOST']    = nil
      ENV['SKYLIGHT_ACCOUNTS_PORT']    = nil
      ENV['SKYLIGHT_ACCOUNTS_SSL']     = nil
      ENV['SKYLIGHT_ACCOUNTS_DEFLATE'] = nil
      Skylight.stop!
    end

    let :token do
      "hey-guyz-i-am-a-token"
    end

    before :each do
      server.mock "/agent/authenticate" do |env|
        { session: { token: token} }
      end
    end

    it 'successfully calls into rails' do
      call MyApp, env('/users')

      server.wait count: 2

      batch = server.reports[0]
      batch.should_not be nil
      batch.should have(1).endpoints
      endpoint = batch.endpoints[0]
      endpoint.name.should == "UsersController#index"
      endpoint.should have(1).traces
      trace = endpoint.traces[0]

      names = trace.spans.map { |s| s.event.category }

      names.length.should be >= 2
      names.should include('app.zomg')
      names.should include('app.inside')
      names[-1].should == 'app.rack.request'
    end

    def call(app, env)
      resp = app.call(env)
      consume(resp)
      nil
    end

    def env(path = '/', opts = {})
      Rack::MockRequest.env_for(path, {})
    end

    def consume(resp)
      resp[2].each { }
      resp[2].close
    end

  end
end
