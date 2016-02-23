# encoding: UTF-8

require 'spec_helper'
require 'date'

module Skylight
  describe "Normalizers", "sql.active_record", :agent do

    it "skips SCHEMA queries" do
      expect(normalize(name: "SCHEMA")).to eq(:skip)
    end

    it "Processes cached queries" do
      name, * = normalize(name: "CACHE", sql: "select * from query")

      expect(name).to eq(:skip)
    end

    it "Processes uncached queries" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo")
    end

    it "Pulls out binds" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id = $1")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id = ?")
    end

    it "Handles queries without a title" do
      sql = "SELECT * from foo"

      name, title, desc =
        normalize(name: nil, sql: sql)

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq(sql)
    end

    it "Handles Rails-style insertions" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES ($1, $2, $3, $4) RETURNING "id"}

      name, title, desc =
        normalize(name: "SQL", sql: sql)

      expect(name).to eq("db.sql.query")
      expect(title).to eq("INSERT INTO agent_errors")
      expect(desc).to eq(%{INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES (?, ?, ?, ?) RETURNING "id"})
    end

    it "Determines embedded binds" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id = 1")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id = ?")
    end

    it "handles some precomputed binds" do
      sql = %{INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason") VALUES ($1, $2, NULL, $3, $4) RETURNING "id"}
      extracted = %{INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason") VALUES (?, ?, ?, ?, ?) RETURNING "id"}

      name, title, desc =
        normalize(name: "SQL", sql: sql)

      expect(name).to eq("db.sql.query")
      expect(title).to eq("INSERT INTO agent_errors")
      expect(desc).to eq(extracted)
    end

    it "Produces an error if the SQL isn't parsable" do
      expect(config.logger).to receive(:warn).with(/failed to extract binds in SQL/).once
      config[:log_sql_parse_errors] = true

      name, title, desc =
        normalize(name: "Foo Load", sql: "!!!")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("Foo Load")
      expect(desc).to eq(nil)
    end

    # The tests below are not strictly necessary, but they ensure that updates to the Rust agent
    # really took so that we don't have a repeat of 0.9.1.

    it "Handles NOT queries" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id not in (1,2)")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id not in ?")
    end

    it "Handles IS queries" do
      name, title, desc =
        normalize(name: "Foo Load", sql: "select * from foo where id is true OR id is not 5")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id is ? OR id is not ?")
    end

    it "Handles typecasting" do
      name, title, desc = normalize(sql: "SELECT foo FROM bar WHERE date::DATE = 'yesterday'::date")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM bar")
      expect(desc).to eq("SELECT foo FROM bar WHERE date::DATE = ?::date")
    end

    it "Handles underscored identifiers" do
      name, title, desc = normalize(sql: "SELECT _bar._foo FROM _bar")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM _bar")
      expect(desc).to eq("SELECT _bar._foo FROM _bar")
    end

    it "Handles multibyte characters" do
      name, title, desc = normalize(sql: "SELECT 𝒜 FROM zømg WHERE foo = 'å'")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM zømg")
      expect(desc).to eq("SELECT 𝒜 FROM zømg WHERE foo = ?")
    end

    it "Handles arrays" do
      name, title, desc = normalize(sql: "SELECT items[1] FROM zomg WHERE items[1] = 1")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM zomg")
      expect(desc).to eq("SELECT items[1] FROM zomg WHERE items[1] = ?")
    end

  end
end
