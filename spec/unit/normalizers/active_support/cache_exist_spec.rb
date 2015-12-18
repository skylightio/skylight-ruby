require "spec_helper"

module Skylight
  describe "Normalizers", "cache_exist?.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      expect(name).to eq("app.cache.exist")
      expect(title).to eq("cache exist?")
      expect(desc).to eq(nil)
    end
  end
end
