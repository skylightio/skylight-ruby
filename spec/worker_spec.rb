require 'spec_helper'

module Skylight
  describe Worker do
    let :config do
      Config.new do |c|
        c.samples_per_interval = 27
        c.interval = 13
        c.max_pending_traces = 1337
        c.protocol = 'json'
      end
    end

    let :instrumenter do
      Instrumenter.new(config)
    end

    let :worker do
      instrumenter.worker
    end

    let :sample do
      double("sample", :clear => true)
    end

    let :queue do
      double("queue", :push => true, :pop => true)
    end

    let :thread do
      double("thread")
    end

    before(:each) do
      Thread.stub(:new).and_return(thread)
      Util::Queue.stub(:new).and_return(queue)
      Util::UniformSample.stub(:new).and_return(sample)
    end

    describe "intialization" do
      it "requires an instrumenter" do
        w = Worker.new(instrumenter)
        w.instrumenter.should == instrumenter
      end

      it "sets up a sample based on config" do
        Util::UniformSample.should_receive(:new).with(27).and_return(sample)
        sample.should_receive(:clear)

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
      let :thread do
        double("thread", :join => true, :kill => true)
      end

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
        thread.should_receive(:join).with(1)
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
        sample.should_receive(:clear).once

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
  end
end
