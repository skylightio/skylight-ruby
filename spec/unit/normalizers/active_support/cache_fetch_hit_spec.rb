require "spec_helper"

module Skylight
  describe "Normalizers", "cache_fetch_hit.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc, payload = normalize(key: "foo")

      name.should == "app.cache.fetch_hit"
      title.should == "cache fetch hit"
      desc.should == nil
      payload.should == { key: "foo" }
    end
  end
end
