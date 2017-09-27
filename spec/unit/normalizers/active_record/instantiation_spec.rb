require 'spec_helper'
require 'date'

module Skylight
  describe "Normalizers", "instantiation.active_record", :agent do
    # Not required by default as it is of dubious usefulness
    require 'skylight/normalizers/active_record/instantiation'

    it "works" do
      category, title, desc =
        normalize({ class_name: "User", record_count: 3 })

      expect(category).to eq("db.active_record.instantiation")
      expect(title).to eq("User")
      expect(desc).to eq(nil)
    end

  end
end
