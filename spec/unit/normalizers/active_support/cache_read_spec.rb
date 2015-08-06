require "spec_helper"

module Skylight
  describe "Normalizers", "cache_read.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      name.should == "app.cache.read"
      title.should == "cache read"
      desc.should == nil
    end
  end
end
