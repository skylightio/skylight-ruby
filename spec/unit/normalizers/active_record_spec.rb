require 'spec_helper'
require 'date'

module Skylight
  describe "Normalizers", "sql.active_record", :agent do

    it "skips SCHEMA queries" do
      normalize(name: "SCHEMA").should == :skip
    end

    it "Processes cached queries" do
      name, * = normalize(name: "CACHE", sql: "select * from query")

      name.should == :skip
    end

    it "Processes uncached queries" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo")

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == "select * from foo"
    end

    it "Pulls out binds" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id = $1")

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == "select * from foo where id = ?"
    end

    it "Handles queries without a title" do
      sql = "SELECT * from foo"

      name, title, desc =
        normalize(name: nil, sql: sql)

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == sql
    end

    it "Handles Rails-style insertions" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES ($1, $2, $3, $4) RETURNING "id"}

      name, title, desc =
        normalize(name: "SQL", sql: sql)

      name.should == "db.sql.query"
      title.should == "INSERT INTO agent_errors"
      desc.should == %{INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES (?, ?, ?, ?) RETURNING "id"}
    end

    it "Determines embedded binds" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id = 1")

      name.should == "db.sql.query"
      title.should == "SELECT FROM foo"
      desc.should == "select * from foo where id = ?"
    end

    it "handles some precomputed binds" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason") VALUES ($1, $2, NULL, $3, $4) RETURNING "id"}
      extracted = %{INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason") VALUES (?, ?, ?, ?, ?) RETURNING "id"}

      name, title, desc =
        normalize(name: "SQL", sql: sql)

      name.should == "db.sql.query"
      title.should == "INSERT INTO agent_errors"
      desc.should == extracted
    end

    it "Produces an error if the SQL isn't parsable" do
      expect(config.logger).to receive(:warn).with(/failed to extract binds in SQL/).once
      config[:log_sql_parse_errors] = true

      name, title, desc =
        normalize(name: "Foo Load", sql: "NOT &REAL& ;;;SQL;;;")

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == nil
    end
  end
end
