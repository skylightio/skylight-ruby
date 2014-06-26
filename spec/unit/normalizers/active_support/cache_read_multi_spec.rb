require "spec_helper"

module Skylight
  describe "Normalizers", "cache_read_multi.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc, payload = normalize(key: ["foo", "bar"])

      name.should == "app.cache.read_multi"
      title.should == "cache read multi"
      desc.should == nil
      payload.should == { key: ["foo", "bar"] }
    end
  end
end
