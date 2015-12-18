require "spec_helper"

module Skylight
  describe "Normalizers", "cache_write.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      expect(name).to eq("app.cache.write")
      expect(title).to eq("cache write")
      expect(desc).to eq(nil)
    end
  end
end
