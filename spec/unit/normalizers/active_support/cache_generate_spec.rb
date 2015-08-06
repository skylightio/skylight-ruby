require "spec_helper"

module Skylight
  describe "Normalizers", "cache_generate.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      name.should == "app.cache.generate"
      title.should == "cache generate"
      desc.should == nil
    end
  end
end
