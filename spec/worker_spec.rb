require 'spec_helper'

module Skylight
  describe Worker do
    let :config do
      Config.new do |c|
        c.samples_per_interval = 27
        c.interval = 13
        c.max_pending_traces = 1337
        c.protocol = 'json'
        c.deflate = false
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

      it "is chainable" do
        worker.submit("trace").should == worker
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
        Trace.new(endpoint).record("testcat")
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

        flushed_batches = []

        worker.stub(:flush) do |batch|
          flushed_batches << batch
        end

        interval = Util.clock.convert(config.interval)
        gap = Util.clock.convert(0.1) # less than hardcoded 0.5s buffer

        trace1 = Trace.new
        trace1.stub(:from => Util.clock.now + interval,
                    :to => Util.clock.now + interval + gap)

        trace2 = Trace.new
        trace2.stub(:from => Util.clock.now + gap,
                    :to => Util.clock.now + interval + gap)

        worker.iter(trace1, Util.clock.now + interval + gap)
        worker.iter(trace2, Util.clock.now + interval + gap)
        worker.iter(nil, Util.clock.now + (interval * 2))

        flushed_batches.length.should == 2
        flushed_batches[0].sample.length.should == 0
        flushed_batches[1].sample.length.should == 2
      end

      it "flushes at interval with small gap" do
        worker.stub(:flush) # so we can spy

        # Make sure interval is set, not ideal way to do it
        worker.send(:reset)

        # We just started the batch
        worker.iter("trace1", Util.clock.at(now))
        worker.should_not have_received(:flush)

        # Batch is over but we have a small gap
        worker.iter("trace2", Util.clock.at(now + config.interval))
        worker.should_not have_received(:flush)

        # Gap is completed, we should flush now
        worker.iter("trace3", Util.clock.at(now + config.interval + 0.6))
        worker.should have_received(:flush)
      end

      it "handles traces for previous batch within window" do
        flushed_batches = []

        worker.stub(:flush) do |batch|
          flushed_batches << batch
        end

        interval = Util.clock.convert(config.interval)
        gap = Util.clock.convert(0.1) # less than hardcoded 0.5s buffer

        trace1 = Trace.new
        trace1.stub(:from => Util.clock.now + interval,
                    :to => Util.clock.now + interval + gap)

        trace2 = Trace.new
        trace2.stub(:from => Util.clock.now + gap,
                    :to => Util.clock.now + interval + gap)

        worker.iter(trace1, Util.clock.now + interval + gap)
        worker.iter(trace2, Util.clock.now + interval + gap)
        worker.iter(nil, Util.clock.now + (interval * 2))

        flushed_batches.length.should == 2
        flushed_batches[0].sample.length.should == 0
        flushed_batches[1].sample.length.should == 2
      end

      it "sends correct data" do
        request = stub_request(:post, "http://#{config.host}:#{config.port}/agent/report")

        # Make sure interval is set, not ideal way to do it
        worker.send(:reset)

        # This stuff would be done in the work method
        worker.send(:http_connect)

        worker.iter(build_trace("Endpoint1"))
        worker.iter(build_trace("Endpoint2"))
        worker.iter(build_trace("Endpoint1"))
        worker.iter(nil, Util.clock.at(now + config.interval + Worker::FLUSH_DELAY))

        request.with do |req|
          json = JSON.parse(req.body)

          json['counts'] == {
            "Endpoint1" => 2,
            "Endpoint2" => 1
          }
        end.should have_been_made
      end
    end

    # Normally we would not test private methods, but I think
    # this deserves an exception
    describe "work" do
      it "waits for items in the queue"
    end
  end
end
