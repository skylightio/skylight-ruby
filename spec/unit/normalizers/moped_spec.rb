require 'spec_helper'

module Skylight
  describe "Normalizers", "query.moped", :moped, :agent do

    it "skips COMMAND" do
      op = Moped::Protocol::Command.new("testdb", { foo: "bar" })
      normalize(ops: [op]).should == :skip
    end

    it "normalizes QUERY" do
      op = Moped::Protocol::Query.new("testdb", "testcollection", { foo: { :"$not" => 'bar' }, baz: 'qux'})
      category, title, description, annotations = normalize(ops: [op])

      category.should    == "db.mongo.query"
      title.should       == "QUERY testcollection"
      description.should == { foo: { :"$not" => '?' }, baz: '?'}.to_json
      annotations.should == { binds: ["bar", "qux"], skip: 0 }
    end

    if defined?(Mongoid)
      class Artist
        include Mongoid::Document
        field :name, type: String
        field :signed_at, type: Time
      end
    end

    it "normalizes QUERY with a Time" do
      Mongoid.load!(File.expand_path("../../../support/mongoid.yml", __FILE__), :development)

      time = Time.now
      artists = Artist.where(signed_at: time)

      category, title, description, annotations = normalize(ops: [artists.query.operation])

      category.should    == "db.mongo.query"
      title.should       == "QUERY skylight_artists"
      description.should == { signed_at: '?' }.to_json
      annotations.should == { binds: [time.utc.to_s], skip: 0 }
    end

    it "normalizes GET_MORE" do
      op = Moped::Protocol::GetMore.new("testdb", "testcollection", "cursor123", 10)
      category, title, description, annotations = normalize(ops: [op])

      category.should    == "db.mongo.query"
      title.should       == "GET_MORE testcollection"
      description.should be_nil
      annotations.should == { limit: 10 }
    end

    it "normalizes INSERT" do
      op = Moped::Protocol::Insert.new("testdb", "testcollection", [{ foo: "bar" }, { baz: "qux" }])
      category, title, description, annotations = normalize(ops: [op])

      category.should    == "db.mongo.query"
      title.should       == "INSERT testcollection"
      description.should be_nil
      annotations.should == { count: 2 }
    end

    it "normalizes UPDATE" do
      op = Moped::Protocol::Update.new("testdb", "testcollection", { foo: "bar" }, { foo: "baz" })
      category, title, description, annotations = normalize(ops: [op])

      category.should    == "db.mongo.query"
      title.should       == "UPDATE testcollection"
      description.should == { selector: { foo: '?' }, update: { foo: '?' } }.to_json
      annotations.should == { binds: { selector: ["bar"], update: ["baz"] } }
    end

    it "normalizes DELETE" do
      op = Moped::Protocol::Delete.new("testdb", "testcollection", { foo: "bar" })
      category, title, description, annotations = normalize(ops: [op])

      category.should    == "db.mongo.query"
      title.should       == "DELETE testcollection"
      description.should == { foo: '?' }.to_json
      annotations.should == { binds: ["bar"] }
    end

  end
end
