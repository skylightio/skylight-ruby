require 'spec_helper'
require 'date'

module Skylight
  describe "Normalizers", "sql.active_record", :agent do

    it "skips SCHEMA queries" do
      normalize(name: "SCHEMA").should == :skip
    end

    it "Processes cached queries" do
      name, * = normalize(name: "CACHE", sql: "select * from query", binds: [])

      name.should == :skip
    end

    it "Processes uncached queries" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo", binds: [])

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == "select * from foo"
    end

    it "Pulls out binds" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id = $1", binds: [[Object.new, 1]])

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == "select * from foo where id = $1"
    end

    it "Handles queries without a title" do
      sql = "SELECT * from foo"

      name, title, desc =
        normalize(name: nil, sql: sql, binds: [])

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == sql
    end

    it "Handles Rails-style insertions" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES ($1, $2, $3, $4) RETURNING "id"}
      body = "hello"
      hostname = "localhost"
      reason = "sql_parse"
      created_at = DateTime.now

      name, title, desc =
        normalize(name: "SQL", sql: sql, binds: [[Object.new, body], [Object.new, created_at], [Object.new, hostname], [Object.new, reason]])

      name.should == "db.sql.query"
      title.should == "INSERT INTO agent_errors"
      desc.should == sql
    end

    it "Determines embedded binds" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id = 1", binds: [])

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == "select * from foo where id = ?"
    end

    it "handles some precomputed binds" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason") VALUES ($1, $2, NULL, $3, $4) RETURNING "id"}
      extracted = %{INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason") VALUES ($1, $2, ?, $3, $4) RETURNING "id"}

      body = "hello"
      hostname = "localhost"
      reason = "sql_parse"
      created_at = DateTime.now

      name, title, desc =
        normalize(name: "SQL", sql: sql, binds: [[Object.new, body], [Object.new, created_at], [Object.new, hostname], [Object.new, reason]])

      name.should == "db.sql.query"
      title.should == "INSERT INTO agent_errors"
      desc.should == extracted
    end

    it "Produces an error if the SQL isn't parsable" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "NOT &REAL& ;;;SQL;;;", binds: [])

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == nil
    end
  end
end
