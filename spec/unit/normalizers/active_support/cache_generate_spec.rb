require "spec_helper"

module Skylight
  describe "Normalizers", "cache_generate.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      expect(name).to eq("app.cache.generate")
      expect(title).to eq("cache generate")
      expect(desc).to eq(nil)
    end
  end
end
