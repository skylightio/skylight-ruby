require 'spec_helper'

module Skylight
  describe Instrumenter do
    let :instrumenter do
      inst = Instrumenter.new(Config.new authentication_token: "foobarbaz")
      inst
    end

    it "starts with a default config" do
      i = Instrumenter.start! authentication_token: "foobarbaz"
      i.config.should be_an_instance_of(Config)
    end

    it "starts with passed config" do
      c = Config.new authentication_token: "foobarbaz"
      i = Instrumenter.start!(c)
      i.config.should == c
    end

    it "has a worker" do
      instrumenter.worker.should be_an_instance_of(Worker)
    end

    it "starts" do
      instrumenter.worker.should_receive(:start!).once
      Subscriber.should_receive(:register!).once

      ret = instrumenter.start!

      ret.should == instrumenter
    end

    describe "tracing" do

      before :each do
        instrumenter.instance_variable_set(:@started, true)
      end

      def run_trace(&block)
        block ||= Proc.new{ a = 1; a }
        instrumenter.trace("Test", &block)
      end

      it "starts a new trace" do
        Trace.should_receive(:new).with(an_instance_of(Config), "Test")
        run_trace
      end

      it "yields the trace" do
        run_trace do |tr|
          tr.should be_an_instance_of(Trace)
        end
      end

      it "commits the trace" do
        Trace.any_instance.should_receive(:commit)
        run_trace
      end

      it "submits the trace to the worker" do
        instrumenter.worker.should_receive(:submit).with(kind_of(Trace))
        run_trace
      end

      it "handles exceptions in tracing" do
        Trace.any_instance.stub(:commit).and_raise

        # This is not a very good way to test
        instrumenter.config.logger.should_receive(:error).once

        run_trace
      end

      it "skips requests that should not be sampled"

      it "only does one per thread" do
        trace = Trace.new
        Trace.should_receive(:new).once.and_return(trace)

        instrumenter.trace do
          run_trace
        end
      end

      it "can have multiple traces for multiple threads" do
        trace = Trace.new
        Trace.should_receive(:new).twice.and_return(trace)

        instrumenter.trace do
          Thread.new { run_trace }.join
        end
      end

    end
  end
end
