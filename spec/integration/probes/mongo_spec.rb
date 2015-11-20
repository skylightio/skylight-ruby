require 'spec_helper'

# Requires mongodb instance to be running
if ENV['TEST_MONGO_INTEGRATION']
  describe 'Mongo integration with offial driver', :mongo_probe, :agent do

    around :each do |example|
      begin
        Skylight::Instrumenter.mock!
        Skylight.trace("Rack") { example.run }
      ensure
        Skylight::Instrumenter.stop!
      end
    end

    let :trace do
      Skylight::Instrumenter.instance.current_trace
    end

    let :client do
      Mongo::Client.new([ 'localhost:27017' ], :database => 'echo_test')
    end

    it "instruments insert_one" do
      # No details on the insert because the documents aren't guaranteed to follow any pattern
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.insert artists", nil).and_call_original.once

      client[:artists].insert_one(name: "Peter")
    end

    it "instruments insert_many" do
      # No details on the insert because the documents aren't guaranteed to follow any pattern
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.insert artists", nil).and_call_original.once

      client[:artists].insert_many([ { name: "Peter" }, { name: "Daniel" } ])
    end

    it "instruments find" do
      # Not showing skip or limit. We could show that they were present, but I think we'd want to hide the value anyway.
      description = { filter: { name: "?" }, sort: { name: -1 } }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.find artists", description).and_call_original.once

      client[:artists].find(name: "Peter").sort(name: -1).skip(10).limit(10).to_a
    end

    it "instruments find distinct" do
      description = { key: "name", query: { name: "?" } }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.distinct artists", description).and_call_original.once

      client[:artists].find(name: "Peter").distinct(:name).to_a
    end

    it "instruments count" do
      description = { query: { name: "?" } }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.count artists", description).and_call_original.once

      client[:artists].find(name: "Peter").count
    end

    it "instruments update_one" do
      description = { updates: [{ "q" => { :name => "?" }, "u" => { "$inc" => { :plays => "?" }}, "multi" => false, "upsert" => false }] }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.update artists", description).and_call_original.once

      client[:artists].find(:name => 'Goldie').update_one("$inc" => { :plays => 1 })
    end

    it "instruments update_many" do
      description = { updates: [{ "q" => { :label => "?" }, "u" => { "$inc" => { :plays => "?" }}, "multi" => true, "upsert" => false }] }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.update artists", description).and_call_original.once

      client[:artists].update_many({ :label => 'Hospital' }, { "$inc" => { :plays => 1 }})
    end

    it "instruments replace_one" do
      description = { updates: [{ "q" => { :name => "?" }, "u" => { "name" => "?" }, "multi" => false, "upsert" => false }] }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.update artists", description).and_call_original.once

      client[:artists].find(:name => 'Aphex Twin').replace_one(:name => 'Richard James')
    end

    it "instruments find_one_and_delete" do
      description = { query: { :name => "?" }, sort: { name: -1 }, remove: true }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.findAndModify artists", description).and_call_original.once

      client[:artists].find(:name => 'Jose James').sort(name: -1).find_one_and_delete
    end

    it "instruments find_one_and_replace" do
      description = { query: { :name => "?" }, update: { name: "?" }, new: true }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.findAndModify artists", description).and_call_original.once

      client[:artists].find(:name => 'Jose James').find_one_and_replace({ :name => 'Jose' }, :return_document => :after)
    end

    it "instruments find_one_and_update" do
      description = { query: { :name => "?" }, update: { "$set" => { name: "?" }}, new: false }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.findAndModify artists", description).and_call_original.once

      client[:artists].find(:name => 'Jose James').find_one_and_update('$set' => { :name => 'Jose' })
    end

    it "instruments delete_one" do
      description = { deletes: [ q: { name: '?' }, limit: 1 ] }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.delete artists", description).and_call_original.once

      client[:artists].find(:name => 'Bjork').delete_one
    end

    it "instruments delete_many" do
      description = { deletes: [ q: { name: '?' }, limit: 0 ] }.to_json
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.delete artists", description).and_call_original.once

      client[:artists].find(:name => 'Bjork').delete_many
    end

    it "instruments bulk_write" do
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.insert artists", anything).and_call_original.once.ordered
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.update artists", anything).and_call_original.once.ordered
      expect(trace).to receive(:instrument).with("db.mongo.command", "echo_test.delete artists", anything).and_call_original.once.ordered

      client[:artists].bulk_write([
        { :insert_one => { :x => 1 } },
        { :update_one => { :filter => { :x => 1 },
                           :update => {'$set' => { :x => 2 }}}},
        { :delete_one => { :filter => { :x => 1 }}}
      ], :ordered => true)
    end

  end
end