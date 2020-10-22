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

    # SQL parsing happens in the daemon
    expect(trace).to receive(:instrument).with(
      "db.sql.query",
      "SQL",
      "<sk-sql>SELECT count(*) AS 'count' FROM `items` LIMIT 1</sk-sql>",
      hash_including({})
    ).and_call_original

    db[:items].count
  end
end
