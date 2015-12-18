require "spec_helper"

module Skylight
  describe "Normalizers", "cache_delete.active_support", :agent do

    it "normalizes the notification name with defaults" do
      name, title, desc = normalize(key: "foo")

      expect(name).to eq("app.cache.delete")
      expect(title).to eq("cache delete")
      expect(desc).to eq(nil)
    end
  end
end
