require 'spec_helper'

module Skylight
  describe "metrics reporting", :http, :agent do

    before :each do
      Skylight.start! config
      clock.freeze
    end

    let :agent_strategy do
      "standalone"
    end

    let :metrics_report_interval do
      2
    end

    before :each do
      Skylight.start! config
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    def mock_auth(t=token)
      server.mock "/agent/authenticate" do |env|
        { session: { token: t } }
      end
    end

    def submit_trace
      Skylight.trace 'Unknown', 'app.rack.request' do
        clock.skip 0.01
      end
    end

    it 'reports metrics' do
      mock_auth
      submit_trace
      clock.unfreeze

      server.wait count: 4, timeout: 15

      server.requests[4..5].each do |req|
        req['PATH_INFO'].should == '/agent/metrics'
        req['rack.input']['report'].keys.sort.should == %w(
          collector.report-rate
          collector.report-success-rate
          host.info
          hostname
          ruby.engine
          ruby.version
          skylight.version
          worker.collector.queue-depth
          worker.ipc.open-connections
          worker.ipc.throughput
          worker.memory
          worker.cpu
          worker.uptime)
      end
    end
  end
end
