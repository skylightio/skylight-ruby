require 'spec_helper'

# Requires mongodb instance to be running
if ENV['TEST_MONGO_INTEGRATION']
  describe 'Mongo integration with Mongoid', :mongoid_probe, :agent do

    around :each do |example|
      begin
        Skylight::Instrumenter.mock!
        Skylight.trace("Rack") { example.run }
      ensure
        Skylight::Instrumenter.stop!
      end
    end

    class Artist
      include Mongoid::Document
      field :name, type: String
      field :signed_at, type: Time
    end

    let :trace do
      Skylight::Instrumenter.instance.current_trace
    end

    let :config do
      "mongoid.yml"
    end

    def make_query
      Mongoid.load!(File.expand_path("../../../support/#{config}", __FILE__), :development)

      # Test with a time here because apparently we had issues with this in the normalizer in the past
      time = Time.now
      artists = Artist.where(signed_at: time)
      artists.first
    end

    require 'mongoid/version'
    version = Gem::Version.new(Mongoid::VERSION)

    if version < Gem::Version.new("5.0")

      let :config do
        "mongoid4.yml"
      end

      it "works" do
        cat = "db.mongo.query"
        title = "QUERY artists"
        payload = { :"$query" => { signed_at: "?" }, :"$orderby" => { _id: "?" }}.to_json
        expect(trace).to receive(:instrument).with(cat, title, payload).and_call_original.once
        make_query
      end

    else

      let :options_hash do
        {
          category: "db.mongo.command",
          title:    "echo_test.find artists",
          description: { filter: { signed_at: "?" }}.to_json
        }
      end

      it "works" do
        expect(Skylight).to receive(:instrument).with(options_hash).and_return(1).once
        expect(Skylight).to receive(:done).with(1).once
        make_query
      end

      it "works if instrumenter returns nil" do
        expect(Skylight).to receive(:instrument).with(options_hash).and_return(nil).once
        make_query
      end

    end

  end
end