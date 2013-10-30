require 'spec_helper'
require 'date'

module Skylight
  describe Normalizers, "sql.active_record" do

    it "skips SCHEMA queries" do
      normalize(name: "SCHEMA").should == :skip
    end

    it "Processes cached queries" do
      name, * = normalize(name: "CACHE", sql: "select * from query", binds: [])

      name.should == :skip
    end

    it "Processes uncached queries" do
      name, title, desc, annotations =
        normalize(name: "Foo Load", sql: "select * from foo", binds: [])

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == "select * from foo"

      annotations.should == {
        sql: "select * from foo",
        binds: []
      }
    end

    it "Pulls out binds" do
      name, title, desc, annotations =
        normalize(name: "Foo Load", sql: "select * from foo where id = $1", binds: [[Object.new, 1]])

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == "select * from foo where id = $1"

      annotations.should == {
        sql: "select * from foo where id = $1",
        binds: ["1"]
      }
    end

    it "Handles queries without a title" do
      sql = "SELECT * from foo"

      name, title, desc, annotations =
        normalize(name: nil, sql: sql, binds: [])

      name.should == "db.sql.query"
      title.should == "SQL"
      desc.should == sql

      annotations.should == {
        sql: sql,
        binds: []
      }
    end

    it "Handles Rails-style insertions" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES ($1, $2, $3, $4) RETURNING "id"}
      body = "hello"
      hostname = "localhost"
      reason = "sql_parse"
      created_at = DateTime.now

      name, title, desc, annotations =
        normalize(name: "SQL", sql: sql, binds: [[Object.new, body], [Object.new, created_at], [Object.new, hostname], [Object.new, reason]])

      name.should == "db.sql.query"
      title.should == "SQL"
      desc.should == sql

      annotations.should == {
        sql: sql,
        binds: ["\"hello\"", created_at.inspect, "\"localhost\"", "\"sql_parse\""]
      }
    end

    it "Determines embedded binds" do
      name, title, desc, annotations =
        normalize(name: "Foo Load", sql: "select * from foo where id = 1", binds: [])

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == "select * from foo where id = ?"

      annotations.should == {
        sql: "select * from foo where id = ?",
        binds: ["1"]
      }
    end

    it "Produces an error if the SQL isn't parsable" do
      name, title, desc, annotations =
        normalize(name: "Foo Load", sql: "NOT &REAL& ;;;SQL;;;", binds: [])

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == nil
      annotations[:skylight_error].should == ["sql_parse", "NOT &REAL& ;;;SQL;;;"]
    end
  end
end
