require 'spec_helper'

module Skylight
  describe Normalizers, "process_action.action_controller" do

    it "updates the trace's endpoint" do
      normalize(controller: "foo", action: "bar")
      trace.endpoint.should == "foo#bar"
    end

    it "allocates", allocations: true do
      payload = { controller: "foo", action: "bar" }

      # prime
      normalize(payload)

      lambda { normalize(payload) }.should allocate(string: 1, array: 1, hash: 1)
    end

    it "ignores unknown keys" do
      name, desc, error, annotation = normalize(request: "why is this here?")
      annotation.should_not have_key(:request)
    end

  end
end
