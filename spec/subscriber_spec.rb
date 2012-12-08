require 'spec_helper'

module Skylight
  describe Subscriber do
    let :subscriber do
      Subscriber.new
    end

    it "should register" do
      ActiveSupport::Notifications.should_receive(:subscribe).with(nil, kind_of(Subscriber))
      Subscriber.register!
    end

    describe "actions" do
      let :trace do
        Trace.new
      end

      let :payload do
        { :key => :value }
      end

      before(:each) do
        Trace.stub(:current).and_return(trace)
      end

      describe "start" do
        it "handles basic actions" do
          trace.should_receive(:start).with("test", nil, payload)
          subscriber.start("test", 1, payload)
        end

        it "sets endpoint for process action" do
          trace.should_receive(:endpoint=).with("test_controller#test_action")

          subscriber.start("process_action.action_controller", 1,
                              :controller => "test_controller",
                              :action     => "test_action")
        end

        it "handles no trace" do
          Trace.stub(:current).and_return(nil)
          lambda{ subscriber.start("test", nil, payload) }.should_not raise_error
        end
      end

      describe "finish" do
        it "stops the trace" do
          trace.should_receive(:stop)
          subscriber.finish("test", 1, payload)
        end

        it "handles no trace" do
          Trace.stub(:current).and_return(nil)
          lambda{ subscriber.finish("test", nil, payload) }.should_not raise_error
        end
      end

      describe "measure" do
        it "records on the trace" do
          trace.should_receive(:record)
          subscriber.measure("test", 1, payload)
        end

        it "handles no trace" do
          Trace.stub(:current).and_return(nil)
          lambda{ subscriber.measure("test", nil, payload) }.should_not raise_error
        end
      end
    end
  end
end
