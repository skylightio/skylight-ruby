require "spec_helper"

module Skylight
  describe "Normalizers", "cache_increment.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo", amount: 1)

      expect(name).to eq("app.cache.increment")
      expect(title).to eq("cache increment")
      expect(desc).to eq(nil)
    end
  end
end
