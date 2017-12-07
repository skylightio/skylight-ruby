require 'spec_helper'
module CouchPotato
  describe "Normalizers", "couch_potato.view" do
    it 'normalizes the view query' do
      name, title, desc = normalize(name: "activity/by_source_id_and_created_at")
      expect(name).to eq("db.couch_db.query")
      expect(title).to eq("view")
      expect(desc).to eq('activity/by_source_id_and_created_at')
    end
  end
  
  describe "Normalizers", "couch_potato.load" do
    it 'normalizes the load query' do
      name, title, desc = normalize
      expect(name).to eq("db.couch_db.query")
      expect(title).to eq("load")
      expect(desc).to be_nil
    end
  end
end