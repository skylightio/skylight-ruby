require 'spec_helper'
require 'skylight/core/instrumenter'

enable = false
begin
  require 'sinatra'
  require 'skylight/sinatra'
  enable = true
rescue LoadError
  puts "[INFO] Skipping Sinatra integration specs"
end

if enable
  describe 'Sinatra integration' do

    before :each do
      ENV['SKYLIGHT_ENABLE_TRACE_LOGS']    = "1"
      ENV['SKYLIGHT_AUTHENTICATION']       = "lulz"
      ENV['SKYLIGHT_BATCH_FLUSH_INTERVAL'] = "1"
      ENV['SKYLIGHT_REPORT_URL']           = "http://127.0.0.1:#{port}/report"
      ENV['SKYLIGHT_REPORT_HTTP_DEFLATE']  = "false"
      ENV['SKYLIGHT_AUTH_URL']             = "http://127.0.0.1:#{port}/agent"
      ENV['SKYLIGHT_VALIDATION_URL']       = "http://127.0.0.1:#{port}/agent/config"
      ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = "false"

      Skylight.start!

      class ::MyApp < ::Sinatra::Base
        get "/test" do
          Skylight.instrument category: 'app.inside' do
            Skylight.instrument category: 'app.zomg' do
              # nothing
            end
            erb "Hello"
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
      ENV['SKYLIGHT_VALIDATION_URL']       = nil
      ENV['SKYLIGHT_AUTH_HTTP_DEFLATE']    = nil

      Skylight.stop!

      # Clean slate
      Object.send(:remove_const, :MyApp)
    end

    let :app do
      Rack::Builder.new { run MyApp }
    end

    context "with agent", :http, :agent do
      before :each do
        stub_config_validation
        stub_session_request
      end

      it 'successfully calls into grape' do
        res = call env('/test')
        expect(res).to eq(["Hello"])

        server.wait resource: '/report'

        batch = server.reports[0]
        expect(batch).to_not be nil
        expect(batch.endpoints.count).to eq(1)
        endpoint = batch.endpoints[0]
        expect(endpoint.name).to eq("GET /test")
        expect(endpoint.traces.count).to eq(1)
        trace = endpoint.traces[0]

        names = trace.spans.map { |s| s.event.category }

        expect(names.length).to be >= 3
        expect(names).to include('app.zomg')
        expect(names).to include('app.inside')
        expect(names[0]).to eq('app.rack.request')
      end

    end

    def call(env)
      resp = app.call(env)
      consume(resp)
    end

    def env(path = '/', opts = {})
      Rack::MockRequest.env_for(path, {})
    end

    def consume(resp)
      data = []
      resp[2].each{|p| data << p }
      resp[2].close if resp[2].respond_to?(:close)
      data
    end
  end
end
