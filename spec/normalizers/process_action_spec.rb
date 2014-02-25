require 'spec_helper'

module Skylight
  describe Normalizers, "process_action.action_controller" do

    it "updates the trace's endpoint" do
      normalize(controller: "foo", action: "bar")
      trace.endpoint.should == "foo#bar"
    end

    it "converts non-Strings or Numerics via inspect" do
      _, _, _, annotation = normalize(params: { foo: "bar" })
      annotation[:params].should == { foo: "bar" }.inspect
    end

    it "ignores unknown keys" do
      _, _, _, annotation = normalize(request: "why is this here?")
      annotation.should_not have_key(:request)
    end

  end
end
