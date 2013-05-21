require 'spec_helper'

module Skylight
  describe Worker::Collector do

    shared_examples "a worker" do

      before :each do
        start_server
        worker.spawn
      end

      it 'has tests' do
        t = trace.build

        worker.submit t
        server.wait

        server.should have(1).requests
        server.should have(1).reports

        batch = server.reports[0]
        batch.timestamp.should be_within(1).of(Time.now.to_i)

        batch.should have(1).endpoints

        t.endpoint = nil
        ep = batch.endpoints[0]
        ep.name.should == 'Unknown'
        ep.traces[0].should == t
      end

    end

    context "embedded" do

      let :worker do
        spawn_worker strategy: 'embedded', interval: 1
      end

      it_behaves_like "a worker"

    end

    context "standalone" do

      let :worker do
        spawn_worker strategy: 'standalone'
      end

      it_behaves_like "a worker"

    end

  end
end
