require "spec_helper"
require "date"

module Skylight::Core
  describe "Normalizers", "*.shrine", :agent do
    # This has the same behavior for all keys specified in
    # Skylight::Core::Normalizers::Shrine::TITLES.
    specify do
      category, title, desc = normalize("upload.shrine")

      expect(category).to eq("app.shrine.upload")
      expect(title).to eq("Shrine Upload")
      expect(desc).to eq(nil)
    end
  end
end
