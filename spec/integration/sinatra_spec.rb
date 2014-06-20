require 'spec_helper'

enable = false
begin
  require 'sinatra/base'
  require 'skylight/sinatra'
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sinatra integration specs"
end

if enable
  class MySinatraApp < Sinatra::Base
    set :root, File.expand_path('../../dummy', __FILE__)

    get '/users' do
      Skylight.instrument category: 'app.inside' do
        Skylight.instrument category: 'app.zomg' do
          # nothing
        end

        "Hello"
      end
    end
  end

  describe 'Sinatra integration' do
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

      MySinatraApp.register(Skylight::Sinatra)
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

    context "with agent", :http, :agent do
      let :token do
        "hey-guyz-i-am-a-token"
      end

      before :each do
        server.mock "/agent/authenticate" do |env|
          { session: { token: token } }
        end
      end

      it "successfully calls into sinatra" do
        call MySinatraApp, env('/users')

        server.wait count: 2

        batch = server.reports[0]
        batch.should_not be nil
        batch.should have(1).endpoints
        endpoint = batch.endpoints[0]
        endpoint.name.should == "GET /users"
        endpoint.should have(1).traces
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
        call(MySinatraApp, env('/users')).should == ["Hello"]
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
      resp[2].each { |p| data << p }
      data
    end
  end
end
