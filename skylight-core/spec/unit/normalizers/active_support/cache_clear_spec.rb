require "spec_helper"

module Skylight
  describe "Normalizers", "cache_clear.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "flushing all keys")

      expect(name).to eq("app.cache.clear")
      expect(title).to eq("cache clear")
      expect(desc).to eq(nil)
    end
  end
end
