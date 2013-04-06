require 'spec_helper'

module Skylight
  describe Normalize, "process_action.action_controller" do
    it "updates the trace's endpoint" do
      trace = Struct.new(:endpoint).new
      Normalize.normalize(trace, "process_action.action_controller", controller: "foo", action: "bar")
      trace.endpoint.should == "foo#bar"
    end
  end
end
