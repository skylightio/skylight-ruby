require "spec_helper"

module Skylight
  describe "Normalizers", "cache_decrement.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo", amount: 1)

      expect(name).to eq("app.cache.decrement")
      expect(title).to eq("cache decrement")
      expect(desc).to eq(nil)
    end
  end
end
