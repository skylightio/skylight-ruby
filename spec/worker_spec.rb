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

      it "sets up a sample based on config" do
        sample = Util::UniformSample.new(27)
        Util::UniformSample.should_receive(:new).with(27).and_return(sample)
        sample.should_receive(:clear).once

        worker
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
        Util::UniformSample.any_instance.should_receive(:clear).once

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

    # Normally we would not test private methods, but I think
    # this deserves an exception
    describe "iter" do

      before(:each) do
        worker.start!
      end

      after(:each) do
        Timecop.return
      end

      def build_trace(endpoint)
        Trace.new(endpoint).record("testcat")
      end

      def process_trace(trace)
        worker.submit(trace)
        worker.send(:iter)
      end

      # Not satisfied with the amount this knows about internals
      it "waits for items in the queue" do
        queue.should_receive(:pop).with(13.to_f / 20)

        worker.send(:iter)
      end

      it "returns true if queue is empty" do
        Timecop.scale(3600) # Reduce wait

        worker.send(:iter).should be_true
      end

      it "flushes if msg is shutdown" do
        Timecop.scale(3600) # Reduce wait

        worker.should_receive(:flush)

        worker.shutdown!

        worker.send(:iter).should be_false
      end

      it "batches traces by end time"

      it "doesn't flush until next batch started"

      it "flushes at interval with small gap" do
        worker.stub(:flush) # so we can spy

        now = Time.now()
        Timecop.freeze(now)

        # Make sure interval is set, not ideal way to do it
        worker.send(:reset)

        # We just started the batch
        process_trace("trace1")
        worker.should_not have_received(:flush)

        # Batch is over but we have a small gap
        Timecop.freeze(now + config.interval)
        process_trace("trace2")
        worker.should_not have_received(:flush)

        # Gap is completed, we should flush now
        Timecop.freeze(now + config.interval + 0.5)
        process_trace("trace3")
        worker.should have_received(:flush)
      end

      it "flushes after timeout if no new iters"

      it "sends correct data" do
        request = stub_request(:post, "http://#{config.host}:#{config.port}/agent/report")

        now = Time.now()
        Timecop.freeze(now)

        # Make sure interval is set, not ideal way to do it
        worker.send(:reset)

        # This stuff would be done in the work method
        worker.send(:reset_counts)
        worker.send(:http_connect)

        process_trace(build_trace("Endpoint1"))
        process_trace(build_trace("Endpoint2"))
        process_trace(build_trace("Endpoint1"))

        # Make sure we flush
        Timecop.freeze(now + config.interval + 0.5)
        # This final trace should not get included in the request
        # since we flush first
        process_trace(build_trace("Endpoint3"))

        request.with do |req|
          json = JSON.parse(req.body)

          json['counts'] == {
            "Endpoint1" => 2,
            "Endpoint2" => 1
          }
        end.should have_been_made
      end
    end
  end
end
