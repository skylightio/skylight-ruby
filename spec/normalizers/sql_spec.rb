require 'spec_helper'

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
        normalize(name: "Foo Load", sql: "select * from foo where id = ?", binds: [[Object.new, 1]])

      name.should == "db.sql.query"
      title.should == "Foo Load"
      desc.should == "select * from foo where id = ?"

      annotations.should == {
        sql: "select * from foo where id = ?",
        binds: [1]
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
  end
end
