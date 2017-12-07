require 'spec_helper'

module Skylight
  describe "Normalizers", "query.moped", :moped do

    it "skips COMMAND" do
      op = Moped::Protocol::Command.new("testdb", { foo: "bar" })
      expect(normalize(ops: [op])).to eq(:skip)
    end

    it "normalizes QUERY" do
      op = Moped::Protocol::Query.new("testdb", "testcollection", { foo: { :"$not" => 'bar' }, baz: 'qux'})
      category, title, description = normalize(ops: [op])

      expect(category).to    eq("db.mongo.query")
      expect(title).to       eq("QUERY testcollection")
      expect(description).to eq({ foo: { :"$not" => '?' }, baz: '?'}.to_json)
    end

    it "normalizes GET_MORE" do
      op = Moped::Protocol::GetMore.new("testdb", "testcollection", "cursor123", 10)
      category, title, description = normalize(ops: [op])

      expect(category).to    eq("db.mongo.query")
      expect(title).to       eq("GET_MORE testcollection")
      expect(description).to be_nil
    end

    it "normalizes INSERT" do
      op = Moped::Protocol::Insert.new("testdb", "testcollection", [{ foo: "bar" }, { baz: "qux" }])
      category, title, description = normalize(ops: [op])

      expect(category).to    eq("db.mongo.query")
      expect(title).to       eq("INSERT testcollection")
      expect(description).to be_nil
    end

    it "normalizes UPDATE" do
      op = Moped::Protocol::Update.new("testdb", "testcollection", { foo: "bar" }, { foo: "baz" })
      category, title, description = normalize(ops: [op])

      expect(category).to    eq("db.mongo.query")
      expect(title).to       eq("UPDATE testcollection")
      expect(description).to eq({ selector: { foo: '?' }, update: { foo: '?' } }.to_json)
    end

    it "normalizes DELETE" do
      op = Moped::Protocol::Delete.new("testdb", "testcollection", { foo: "bar" })
      category, title, description = normalize(ops: [op])

      expect(category).to    eq("db.mongo.query")
      expect(title).to       eq("DELETE testcollection")
      expect(description).to eq({ foo: '?' }.to_json)
    end

  end
end
