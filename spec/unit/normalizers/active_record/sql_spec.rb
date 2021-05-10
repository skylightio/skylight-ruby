require "spec_helper"
require "date"

module Skylight
  describe "Normalizers", "sql.active_record", :http, :agent do
    before :each do
      ENV["SKYLIGHT_AUTHENTICATION"] = "lulz"
      ENV["SKYLIGHT_VALIDATION_URL"] = "http://127.0.0.1:#{port}/agent/config"

      Skylight.start!

      # Start a trace to have it available in the trace method
      Skylight.trace("Test", "app.request")

      stub_const("ActiveRecord::Base", double(connection_config: { adapter: "postgres", database: "testdb" }))
    end

    after :each do
      ENV["SKYLIGHT_AUTHENTICATION"] = nil
      ENV["SKYLIGHT_VALIDATION_URL"] = nil
      Skylight.stop!
    end

    def trace
      Skylight.instrumenter.current_trace
    end

    def config
      Skylight.config
    end

    it "skips SCHEMA queries" do
      expect(normalize(name: "SCHEMA")).to eq(:skip)
    end

    it "Processes cached queries" do
      name, * = normalize(name: "CACHE", sql: "select * from query")

      expect(name).to eq(:skip)
    end

    it "Processes uncached queries" do
      name, title, desc = normalize(name: "Foo Load", sql: "select * from foo")

      expect(name).to eq("db.sql.query")
      expect(title).to eq("Foo Load")
      expect(desc).to eq("<sk-sql>select * from foo</sk-sql>")
    end
  end
end
