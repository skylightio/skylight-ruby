require 'spec_helper'

describe 'Sequel integration', :sequel_probe, :agent do
  around do |example|
    Skylight::Instrumenter.mock!
    Skylight.trace("Rack") { example.run }
  end

  after do
    Skylight::Instrumenter.stop!
  end

  let(:trace) {
    Skylight::Instrumenter.instance.current_trace
  }

  it "instruments SQL queries" do
    db = Sequel.sqlite
    db.create_table :items do
      primary_key :id
      String :name
    end

    trace.should_receive(:instrument).with(
      'db.sql.query', 'SELECT FROM items', 'SELECT COUNT(*) AS ? FROM `items` LIMIT ?', anything
    ).and_call_original

    db[:items].count
  end
end
