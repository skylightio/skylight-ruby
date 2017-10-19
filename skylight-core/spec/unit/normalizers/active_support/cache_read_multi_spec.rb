require "spec_helper"

module Skylight
  describe "Normalizers", "cache_read_multi.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: ["foo", "bar"])

      expect(name).to eq("app.cache.read_multi")
      expect(title).to eq("cache read multi")
      expect(desc).to eq(nil)
    end
  end
end
