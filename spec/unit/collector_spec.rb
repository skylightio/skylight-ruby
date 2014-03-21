require 'spec_helper'

module Skylight
  describe Worker::Collector, :http do

    before :each do
      Skylight.start! config
      clock.freeze
    end

    after :each do
      Skylight.stop!
    end

    shared_examples "a worker" do |strategy|

      let(:agent_strategy) { strategy }

      let :token do
        "hey-guyz-i-am-a-token"
      end

      let :token2 do
        "hey-guyz-i-am-another-token"
      end

      def submit_trace
        Skylight.trace 'Unknown', 'app.rack.request' do
          clock.skip 0.01
        end
      end

      def mock_auth(t=token)
        server.mock "/agent/authenticate" do |env|
          { session: { token: t } }
        end
      end

      it 'submits the batch to the server' do
        mock_auth

        submit_trace

        clock.unfreeze
        server.wait count: 3

        server.should have(3).requests
        server.should have(1).reports

        # Token verification
        req = server.requests[0]
        req['PATH_INFO'].should == '/agent/authenticate'
        req['HTTP_X_SKYLIGHT_AGENT_VERSION'].should == Skylight::VERSION
        req['HTTP_AUTHORIZATION'].should == 'lulz'

        # Session authentication
        req = server.requests[1]
        req['PATH_INFO'].should == '/agent/authenticate'
        req['HTTP_X_SKYLIGHT_AGENT_VERSION'].should == Skylight::VERSION
        req['HTTP_AUTHORIZATION'].should == 'lulz'

        # Report
        req = server.requests[2]
        req['PATH_INFO'].should == '/report'
        req['HTTP_X_SKYLIGHT_AGENT_VERSION'].should == Skylight::VERSION
        req['HTTP_AUTHORIZATION'].should == token
        req['CONTENT_TYPE'].should == 'application/x-skylight-report-v2'

        batch = server.reports[0]
        batch.timestamp.should be_within(3).of(Util::Clock.absolute_secs)
        batch.hostname.should == Socket.gethostname

        batch.should have(1).endpoints

        ep = batch.endpoints[0]
        ep.name.should == 'Unknown'
        @trace = ep.traces[0]
        trace.should have(1).spans

        span(0).event.category.should == 'app.rack.request'
      end

      it 'refreshes the session token every 10 minutes' do
        mock_auth

        submit_trace
        clock.unfreeze
        server.wait count: 2
        clock.freeze

        submit_trace
        clock.unfreeze
        server.wait count: 3
        clock.freeze

        server.should have(3).requests

        req = server.requests[0]
        req['HTTP_AUTHORIZATION'].should == 'lulz'

        server.requests[2]['HTTP_AUTHORIZATION'].should == token

        mock_auth token2
        clock.skip 3600

        submit_trace
        clock.unfreeze
        server.wait count: 5

        server.should have(5).requests

        req = server.requests[4]
        req['HTTP_AUTHORIZATION'].should == token2
      end unless strategy == :standalone

      it 'uses the old token if the accounts server cannot provide a new one' do
        mock_auth

        submit_trace
        clock.unfreeze
        server.wait count: 3
        clock.freeze

        submit_trace
        clock.unfreeze
        server.wait count: 4
        clock.freeze

        server.should have(4).requests
        req = server.requests[1]
        req['PATH_INFO'].should == '/agent/authenticate'
        req['HTTP_AUTHORIZATION'].should == 'lulz'

        server.requests[2, 3].each do |req|
          req['PATH_INFO'].should == '/report'
          req['HTTP_AUTHORIZATION'].should == token
        end

        clock.skip 3600
        submit_trace
        clock.unfreeze
        server.wait count: 5

        server.should have(5).requests

        req = server.requests[4]
        req['PATH_INFO'].should == '/agent/authenticate'
        req['HTTP_AUTHORIZATION'].should == 'lulz'

        # This tests seems like it duplicates the test in the #each above
        req = server.requests[3]
        req['PATH_INFO'].should == '/report'
        req['HTTP_AUTHORIZATION'].should == token
      end unless strategy == :standalone

      context "with crashing report server" do

        let :config do
          @config ||= Skylight::Config.new(test_config_values.merge(
            report: {
              host: "localhost",
              port: 60000,
              ssl: false,
              deflate: false
            }
          ))
        end

        it "sends exceptions while making HTTP requests" do
          mock_auth

          submit_trace

          server.wait count: 3

          req = server.requests[2]
          req['rack.input']["class_name"].should == "Errno::ECONNREFUSED"
          req['PATH_INFO'].should == '/agent/exception'
        end

      end

    end

    context "embedded" do

      it_behaves_like "a worker", :embedded

    end

    context "standalone" do

      it_behaves_like "a worker", :standalone

    end unless defined?(JRUBY_VERSION)

  end
end
