require 'spec_helper'

module Skylight
  describe Worker do
    let :clock do
      Util.clock
    end

    let :config do
      Config.new do |c|
        c.authentication_token = "foobarbaz"
        c.samples_per_interval = 27
        c.interval             = 13
        c.max_pending_traces   = 1337
        c.protocol             = 'json'
        c.deflate              = false
      end
    end

    let :instrumenter do
      Instrumenter.new(config)
    end

    let :worker do
      instrumenter.worker
    end

    # I would prefer to use an actual queue, but its complexity
    # makes it hard to test. It implements standard array methods
    # with the exception of the timeout argument for pop, so this
    # should be fine
    let :queue do
      arr = []
      def arr.pop(timeout = nil) super() end
      arr
    end

    let :thread do
      double("thread", :join => true, :kill => true)
    end

    before(:each) do
      Util::Queue.stub(:new).and_return(queue)
      Thread.stub(:new).and_return(thread)
    end

    describe "intialization" do
      it "requires an instrumenter" do
        w = Worker.new(instrumenter)
        w.instrumenter.should == instrumenter
      end

      it "sets up a queue based on config" do
        Util::Queue.should_receive(:new).with(1337)

        worker
      end
    end

    describe "start" do
      it "sets up a new thread" do
        Thread.should_receive(:new).once
        worker.start!
      end

      it "shuts down if it has a thread" do
        worker.should_receive(:shutdown!).once
        worker.start!
        worker.start!
      end

      it "is chainable" do
        worker.start!.should == worker
      end

      it "does work" do
        # It's probably not appropriate to check a private method here
        worker.should_receive(:work).once
        Thread.stub(:new).and_yield.and_return(thread)
        worker.start!
      end
    end

    describe "shutdown" do
      before(:each) do
        Thread.stub(:new).and_return(thread)
        worker.start!
      end

      # This test is of limited usefulness
      it "does nothing if no thread" do
        thread.should_receive(:join).once
        worker.shutdown! # joins here

        worker.shutdown! # nothing here
      end

      it "pushes shutdown to the queue" do
        queue.should_receive(:push).with(:SHUTDOWN)
        worker.shutdown!
      end

      it "joins the thread if possible" do
        thread.should_receive(:join).with(5)
        worker.shutdown!
      end

      it "kills the thread if it can't join" do
        thread.stub(:join).and_return(false)
        thread.should_receive(:kill)
        worker.shutdown!
      end

      it "swallows ThreadErrors" do
        thread.stub(:join).and_return(false)
        thread.stub(:kill).and_raise(ThreadError)
        lambda{ worker.shutdown! }.should_not raise_error
      end

      it "resets" do
        Util::Queue.should_receive(:new).once.with(1337)

        worker.shutdown!
      end

      it "is chainable" do
        worker.shutdown!.should == worker
      end
    end

    describe "submit" do
      it "pushes to the queue" do
        queue.should_receive(:push).with("trace")
        worker.start!
        worker.submit("trace")
      end

      it "does nothing without a thread" do
        queue.should_not_receive(:push)
        worker.submit("trace")
      end
    end

    describe "iter" do

      before(:each) do
        worker.start!
      end

      let :now do
        Time.at((Time.now.to_i / config.interval) * config.interval);
      end

      def build_trace(endpoint)
        Trace.new(endpoint).record("testcat", nil, nil, nil)
      end

      def do_iter(iters)
        batches = []

        worker.stub(:flush) do |batch|
          batches << batch
        end

        iters.each do |iter|
          if iter[:trace].is_a?(Hash)
            trace = Trace.new
            trace.stub(iter[:trace])
          else
            trace = iter[:trace]
          end

          worker.iter(trace, iter[:received] || (trace && trace.to))
        end

        batches
      end

      it "flushes if msg is shutdown" do
        # Once for each batch
        worker.should_receive(:flush).twice

        worker.iter(:SHUTDOWN).should be_false
      end

      it "batches traces by end time" do
        # Batch 1
        # Batch 2
        # Trace 1 - Starts in Batch 2 ends in Batch 2
        # Trace 2 - Starts in Batch 1 ends <0.5s into Batch 2
        # Both should end up in Batch 2

        batches = do_iter([
          { :trace => {
              :from => clock.at(now + config.interval),
              :to => clock.at(now + config.interval + 0.1) } },
          { :trace => {
              :from => clock.at(now + config.interval + 0.1),
              :to => clock.at(now + config.interval + 0.1) } },
          { :trace => nil,
            :received => clock.at(now + (config.interval * 2)) + Worker::FLUSH_DELAY }
        ])

        batches.length.should == 2
        batches[0].sample.length.should == 0
        batches[1].sample.length.should == 2
      end

      it "handles traces for previous batch within window" do
        window = Worker::FLUSH_DELAY

        batches = do_iter([
          # Should be in Batch 2
          { :trace => {
              :from => clock.at(now + config.interval),
              :to   => clock.at(now + config.interval + 0.1) } },
          # Should be in Batch 1
          { :trace => {
              :from => clock.at(now),
              :to   => clock.at(now + 0.1) },
            :received => clock.at(now + config.interval - 0.1) + window },
          # Would have been in Batch 1, but now out of window
          { :trace => {
              :from => clock.at(now),
              :to   => clock.at(now + 0.1) },
            :received  => clock.at(now + config.interval) + window },
          # Force a flush
          { :trace => nil,
            :received => clock.at(now + (config.interval * 2)) + window }
        ])

        batches.length.should == 2
        batches[0].sample.length.should == 1
        batches[1].sample.length.should == 1
      end

      it "sends correct data" do
        request = stub_request(:post, "https://#{config.host}/report")

        # Make sure interval is set, not ideal way to do it
        worker.send(:reset)

        worker.iter(build_trace("Endpoint1"))
        worker.iter(build_trace("Endpoint2"))
        worker.iter(build_trace("Endpoint1"))
        worker.iter(nil, clock.at(now + config.interval + Worker::FLUSH_DELAY))

        request.with do |req|
          json = JSON.parse(req.body)

          # TODO: Make a more detailed test
          json['batch']['timestamp'] == now.to_i &&
            json['batch']['endpoints'].length == 2
        end.should have_been_made
      end

      it "does not make HTTP requests if there is no authentication_token" do
        config.authentication_token = nil

        request = stub_request(:post, "http://#{config.host}:#{config.port}/report")

        # Make sure interval is set, not ideal way to do it
        worker.send(:reset)

        worker.iter(build_trace("Endpoint1"))
        worker.iter(build_trace("Endpoint2"))
        worker.iter(build_trace("Endpoint1"))
        worker.iter(nil, clock.at(now + config.interval + Worker::FLUSH_DELAY))

        request.should_not have_been_made
      end
    end

    # Normally we would not test private methods, but I think
    # this deserves an exception
    describe "work" do
      it "waits for items in the queue"
    end
  end
end
