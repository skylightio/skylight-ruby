require 'spec_helper'

# Requires mongodb instance to be running
if ENV['TEST_MONGO_INTEGRATION']
  describe 'Mongo integration with offial driver', :mongo_probe, :instrumenter do

    let :client do
      Mongo::Client.new([ 'localhost:27017' ], :database => 'echo_test')
    end

    it "instruments insert_one" do
      client[:artists].insert_one(name: "Peter")

      # No details on the insert because the documents aren't guaranteed to follow any pattern
      expected = {
        cat: "db.mongo.command",
        title: "echo_test.insert artists"
      }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments insert_many" do
      client[:artists].insert_many([ { name: "Peter" }, { name: "Daniel" } ])

      # No details on the insert because the documents aren't guaranteed to follow any pattern
      expected = { cat: "db.mongo.command", title: "echo_test.insert artists" }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments find" do
      client[:artists].find(name: "Peter").sort(name: -1).skip(10).limit(10).to_a

      # Not showing skip or limit. We could show that they were present, but I think we'd want to hide the value anyway.
      description = { filter: { name: "?" }, sort: { name: -1 } }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.find artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments find distinct" do
      client[:artists].find(name: "Peter").distinct(:name).to_a

      description = { key: "name", query: { name: "?" } }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.distinct artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments count" do
      client[:artists].find(name: "Peter").count

      description = { query: { name: "?" } }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.count artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments update_one" do
      client[:artists].find(:name => 'Goldie').update_one("$inc" => { :plays => 1 })

      description = { updates: [{ "q" => { :name => "?" }, "u" => { "$inc" => { :plays => "?" }}, "multi" => false, "upsert" => false }] }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.update artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments update_many" do
      client[:artists].update_many({ :label => 'Hospital' }, { "$inc" => { :plays => 1 }})

      description = { updates: [{ "q" => { :label => "?" }, "u" => { "$inc" => { :plays => "?" }}, "multi" => true, "upsert" => false }] }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.update artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments replace_one" do
      client[:artists].find(:name => 'Aphex Twin').replace_one(:name => 'Richard James')

      description = { updates: [{ "q" => { :name => "?" }, "u" => { "name" => "?" }, "multi" => false, "upsert" => false }] }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.update artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments find_one_and_delete" do
      client[:artists].find(:name => 'Jose James').sort(name: -1).find_one_and_delete

      description = { query: { :name => "?" }, sort: { name: -1 }, remove: true }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.findAndModify artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments find_one_and_replace" do
      client[:artists].find(:name => 'Jose James').find_one_and_replace({ :name => 'Jose' }, :return_document => :after)

      description = { query: { :name => "?" }, update: { name: "?" }, new: true }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.findAndModify artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments find_one_and_update" do
      client[:artists].find(:name => 'Jose James').find_one_and_update('$set' => { :name => 'Jose' })

      description = { query: { :name => "?" }, update: { "$set" => { name: "?" }}, new: false }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.findAndModify artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments delete_one" do
      client[:artists].find(:name => 'Bjork').delete_one

      description = { deletes: [ q: { name: '?' }, limit: 1 ] }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.delete artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments delete_many" do
      client[:artists].find(:name => 'Bjork').delete_many

      description = { deletes: [ q: { name: '?' }, limit: 0 ] }.to_json
      expected = { cat: "db.mongo.command", title: "echo_test.delete artists", desc: description }
      expect(current_trace.mock_spans[1]).to include(expected)
    end

    it "instruments bulk_write" do
      client[:artists].bulk_write([
        { :insert_one => { :x => 1 } },
        { :update_one => { :filter => { :x => 1 },
                           :update => {'$set' => { :x => 2 }}}},
        { :delete_one => { :filter => { :x => 1 }}}
      ], :ordered => true)

      expected = { cat: "db.mongo.command", title: "echo_test.insert artists" }
      expect(current_trace.mock_spans[1]).to include(expected)

      expected = { cat: "db.mongo.command", title: "echo_test.update artists" }
      expect(current_trace.mock_spans[2]).to include(expected)

      expected = { cat: "db.mongo.command", title: "echo_test.delete artists" }
      expect(current_trace.mock_spans[3]).to include(expected)

    end

  end
end