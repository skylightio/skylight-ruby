require 'spec_helper'

# Requires mongodb instance to be running
if ENV['TEST_MONGO_INTEGRATION']
  describe 'Mongo integration with Mongoid', :mongoid_probe, :instrumenter do

    class Artist
      include Mongoid::Document
      field :name, type: String
      field :signed_at, type: Time
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
      # Moped

      let :config do
        "mongoid4.yml"
      end

      it "works" do
        make_query

        expected = {
          cat: "db.mongo.query",
          title: "QUERY artists",
          desc: { :"$query" => { signed_at: "?" }, :"$orderby" => { _id: "?" }}.to_json
        }
        expect(current_trace.mock_spans[1]).to include(expected)
      end

    else
      # Mongo Ruby Driver

      let :options_hash do
        {
          cat:   "db.mongo.command",
          title: "echo_test.find artists",
          desc:  { filter: { signed_at: "?" }}.to_json
        }
      end

      it "works" do
        make_query

        expect(current_trace.mock_spans[1]).to include(options_hash)
      end

      # FIXME: This doesn't actually test what we want, since an exception
      #   will be caught by the probe's error handling.
      it "works if instrumenter returns nil" do
        allow(Skylight).to receive(:instrument).and_return(nil)
        make_query
      end

    end

  end
end