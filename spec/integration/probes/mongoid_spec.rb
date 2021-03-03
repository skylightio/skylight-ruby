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

  def make_query
    ::Mongoid.load!(File.expand_path("../../support/mongoid.yml", __dir__), :development)

    # Test with a time here because apparently we had issues with this in the normalizer in the past
    time = Time.now
    artists = Artist.where(signed_at: time)
    artists.first
  end

  it "works" do
    make_query

    # Mongo Ruby Driver
    expected = {
      cat:   "db.mongo.command",
      title: "echo_test.find artists",
      desc:  { filter: { signed_at: "?" }, sort: { "_id" => 1 } }.to_json
    }

    expect(current_trace.mock_spans[1]).to include(expected)
  end

  # FIXME: This doesn't actually test what we want, since an exception
  #   will be caught by the probe's error handling.
  it "works if instrumenter returns nil" do
    allow(Skylight).to receive(:instrument).and_return(nil)
    make_query
  end
end
