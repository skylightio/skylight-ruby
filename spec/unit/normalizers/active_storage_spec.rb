require "spec_helper"
require "date"

module Skylight
  describe "Normalizers", "*.active_storage", :agent do
    # This has the same behavior for all keys specified in
    # Skylight::Normalizers::ActiveStorage::TITLES.
    specify do
      category, title, desc = normalize("preview.active_storage")

      expect(category).to eq("app.active_storage.preview")
      expect(title).to eq("ActiveStorage Preview")
      expect(desc).to eq(nil)
    end
  end
end
