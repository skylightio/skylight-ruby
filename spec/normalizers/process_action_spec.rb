require 'spec_helper'

module Skylight
  describe Normalizers, "process_action.action_controller" do

    it "updates the trace's endpoint" do
      normalize(trace, "process_action.action_controller", controller: "foo", action: "bar")
      trace.endpoint.should == "foo#bar"
    end

  end
end
