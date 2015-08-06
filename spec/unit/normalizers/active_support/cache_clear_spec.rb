require "spec_helper"

module Skylight
  describe "Normalizers", "cache_clear.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "flushing all keys")

      name.should == "app.cache.clear"
      title.should == "cache clear"
      desc.should == nil
    end
  end
end
