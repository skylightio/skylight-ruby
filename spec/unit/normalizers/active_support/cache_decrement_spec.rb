require "spec_helper"

module Skylight
  describe "Normalizers", "cache_decrement.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo", amount: 1)

      name.should == "app.cache.decrement"
      title.should == "cache decrement"
      desc.should == nil
    end
  end
end
