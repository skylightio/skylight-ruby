require "spec_helper"

describe "Sequel integration", :sequel_probe, :agent do
  class RegexMatcher
    def initialize(regex)
      @regex = regex
    end

    def ==(other)
      # rubocop:disable Style/CaseEquality
      @regex === other
      # rubocop:enable Style/CaseEquality
    end

    def description
      "like #{@regex.inspect}"
    end
  end

  around do |example|
    Skylight.mock!
    Skylight.trace("Rack") { example.run }
  end

  after do
    Skylight.stop!
  end

  let(:trace) do
    Skylight.instrumenter.current_trace
  end

  it "instruments SQL queries" do
    db = Sequel.sqlite
    db.create_table :items do
      primary_key :id
      String :name
    end

    db[:items].count

    expect(trace).to receive(:instrument).with(
      "db.sql.query",
      "SELECT FROM items",
      RegexMatcher.new(/^SELECT count\(\*\) AS \? FROM `items` LIMIT \?$/i),
      nil
    ).and_call_original

    db[:items].count
  end
end
