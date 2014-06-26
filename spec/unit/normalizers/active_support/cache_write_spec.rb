require "spec_helper"

module Skylight
  describe "Normalizers", "cache_write.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc, payload = normalize(key: "foo")

      name.should == "app.cache.write"
      title.should == "cache write"
      desc.should == nil
      payload.should == { key: "foo" }
    end
  end
end
