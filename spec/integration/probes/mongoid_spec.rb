require "spec_helper"

# Requires mongodb instance to be running
describe "Mongo integration with Mongoid", :mongo_probe, :mongoid_probe, :instrumenter, :agent do
  before do
    stub_const(
      "Artist",
      Class.new do
        include ::Mongoid::Document
        store_in collection: "artists"

        field :name, type: String
        field :signed_at, type: Time
      end
    )
  end

  let :is_mongoid4 do
    require "mongoid/version"
    version = Gem::Version.new(::Mongoid::VERSION)
    version < Gem::Version.new("5.0")
  rescue LoadError
    false
  end

  let :config do
    is_mongoid4 ? "mongoid4.yml" : "mongoid.yml"
  end

  def make_query
    ::Mongoid.load!(File.expand_path("../../../support/#{config}", __FILE__), :development)

    # Test with a time here because apparently we had issues with this in the normalizer in the past
    time = Time.now
    artists = Artist.where(signed_at: time)
    artists.first
  end

  it "works" do
    make_query

    expected =
      if is_mongoid4
        # Moped
        {
          cat:   "db.mongo.query",
          title: "QUERY artists",
          desc:  { "$query": { signed_at: "?" }, "$orderby": { _id: "?" } }.to_json
        }
      else
        # Mongo Ruby Driver
        {
          cat:   "db.mongo.command",
          title: "echo_test.find artists",
          desc:  { filter: { signed_at: "?" }, sort: { "_id" => 1 } }.to_json
        }
      end

    expect(current_trace.mock_spans[1]).to include(expected)
  end

  # FIXME: This doesn't actually test what we want, since an exception
  #   will be caught by the probe's error handling.
  it "works if instrumenter returns nil" do
    skip if is_mongoid4

    allow(Skylight).to receive(:instrument).and_return(nil)
    make_query
  end
end
