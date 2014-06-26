require "spec_helper"

module Skylight
  describe "Normalizers", "cache_increment.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc, payload = normalize(key: "foo", amount: 1)

      name.should == "app.cache.increment"
      title.should == "cache increment"
      desc.should == nil
      payload.should == { key: "foo", amount: 1 }
    end
  end
end
