require "spec_helper"

module Skylight
  describe Normalizers, "send_file.action_controller" do

    it "normalizes the notification name with defaults" do
      name, title, desc, payload =
        normalize(path: "foo/bar")

      name.should == "app.controller.send_file"
      title.should == "send file"
      desc.should == nil

      # Rails defaults
      payload.should == {
        path: "foo/bar",
        filename: nil,
        type: 'application/octet-stream',
        disposition: 'attachment',
        status: 200
      }
    end

    it "allocates lightly when normalizing the notification name with defaults", allocations: true do
      payload = { path: "foo/bar" }

      # prime
      normalize(payload)

      lambda { normalize(payload) }.should allocate(array: 1, hash: 1)
    end

    it "normalizes symbol types into their full name" do
      _, _, _, payload = normalize(path: "foo/bar", type: :html)
      payload[:type].should == "text/html"
    end

    it "allocates lightly when normalizing symbols", allocations: true do
      payload = { path: "foo/bar", type: :html }

      # prime
      normalize(payload)

      lambda { normalize(payload) }.should allocate(array: 1, hash: 1)
    end

    it "supports alternative content dispositions" do
      _, _, _, payload = normalize(path: "foo/bar", disposition: "inline")
      payload[:disposition].should == "inline"
    end

    it "allocates lightly with alternate dispositions", allocations: true do
      payload = { path: "foo/bar", disposition: "inline" }

      # prime
      normalize(payload)

      lambda { normalize(payload) }.should allocate(array: 1, hash: 1)
    end

    it "supports alternative statuses" do
      _, _, _, payload = normalize(path: "foo/bar", status: 404)
      payload[:status].should == 404
    end

    it "supports symbolic statuses" do
      _, _, _, payload = normalize(path: "foo/bar", status: :not_found)
      payload[:status].should == 404
    end
  end
end
