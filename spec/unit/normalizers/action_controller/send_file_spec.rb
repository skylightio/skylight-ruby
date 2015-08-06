require "spec_helper"

if defined?(Rails)
  module Skylight
    describe "Normalizers", "send_file.action_controller", :agent do

      it "normalizes the notification name with defaults" do
        skip("Not testing Rails") unless defined?(Rails)

        name, title, desc =
          normalize(path: "foo/bar")

        name.should == "app.controller.send_file"
        title.should == "send file"
        desc.should == nil
      end
    end
  end
end
