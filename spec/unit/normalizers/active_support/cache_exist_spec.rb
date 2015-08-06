require "spec_helper"

module Skylight
  describe "Normalizers", "cache_exist?.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      name.should == "app.cache.exist"
      title.should == "cache exist?"
      desc.should == nil
    end
  end
end
