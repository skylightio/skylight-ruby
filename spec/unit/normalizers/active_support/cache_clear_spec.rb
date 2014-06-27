require "spec_helper"

module Skylight
  describe "Normalizers", "cache_clear.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc, payload = normalize(key: "flushing all keys")

      name.should == "app.cache.clear"
      title.should == "cache clear"
      desc.should == nil
      payload.should == { key: "flushing all keys" }
    end
  end
end
