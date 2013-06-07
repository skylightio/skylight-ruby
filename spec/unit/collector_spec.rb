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

    shared_examples "a worker" do

      before :each do
        Skylight.trace 'Unknown', 'app.rack.request' do
          clock.skip 0.01
        end

        clock.unfreeze
        server.wait
      end

      it 'submits the batch to the server' do
        server.should have(1).requests
        server.should have(1).reports

        req = server.requests[0]
        req['CONTENT_TYPE'].should == 'application/x-skylight-report-v1'

        batch = server.reports[0]
        batch.timestamp.should be_within(3).of(Time.now.to_i)

        batch.should have(1).endpoints

        ep = batch.endpoints[0]
        ep.name.should == 'Unknown'
        @trace = ep.traces[0]
        trace.should have(1).spans

        span(0).event.category.should == 'app.rack.request'
      end

    end

    context "embedded" do

      let(:agent_strategy) { 'embedded' }

      it_behaves_like "a worker"

    end

    context "standalone" do

      let(:agent_strategy) { 'standalone' }

      it_behaves_like "a worker"

    end unless defined?(JRUBY_VERSION)

  end
end
