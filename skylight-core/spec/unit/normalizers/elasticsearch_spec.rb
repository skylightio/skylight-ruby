require 'spec_helper'

module Skylight
  describe "Normalizers", "request.elasticsearch", :elasticsearch do

    it "normalizes PUT index" do
      category, title, description = normalize(method: 'PUT', path: 'foo')
      expect(category).to    eq("db.elasticsearch.request")
      expect(title).to       eq("PUT foo")
      expect(description).to be_nil
    end

    it "normalizes GET type" do
      category, title, description = normalize(method: 'GET', path: 'foo/bar/baz')
      expect(category).to    eq("db.elasticsearch.request")
      expect(title).to       eq("GET foo")
      expect(description).to eq("{\"type\":\"bar\",\"id\":\"?\"}")
    end
  end
end
