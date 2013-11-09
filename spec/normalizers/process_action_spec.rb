require 'spec_helper'

module Skylight
  describe Normalizers, "process_action.action_controller" do

    it "updates the trace's endpoint" do
      normalize(controller: "foo", action: "bar")
      trace.endpoint.should == "foo#bar"
    end

    it "allocates" do
      payload = { controller: "foo", action: "bar" }

      # prime
      normalize(payload)

      lambda { normalize(payload) }.should allocate(string: 1, array: 1, hash: 1)
    end

  end
end
