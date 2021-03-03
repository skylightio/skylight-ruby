require "spec_helper"

# Requires elasticsearch instance to be running
describe "Elasticsearch integration", :elasticsearch_probe, :instrumenter, :agent do
  let(:client) do
    Elasticsearch::Client.new
  end

  before do
    # Delete index if it exists
    Skylight.disable do
      client.indices.delete(index: "skylight-test") rescue nil
    end
  end

  shared_examples_for "instrumented elasticsearch" do
    it "instruments" do
      client.indices.create(index: "skylight-test")

      expect(current_trace.mock_spans).to include(
        a_hash_including(
          cat:   "db.elasticsearch.request",
          title: "PUT skylight-test"
        )
      )

      client.index(index: "skylight-test", type: "person", id: "1", body: { name: "Joe" })

      expect(current_trace.mock_spans).to include(
        a_hash_including(
          cat:   "db.elasticsearch.request",
          title: "PUT skylight-test",
          desc:  { type: "person", id: "?" }.to_json
        )
      )
    end
  end

  it_behaves_like "instrumented elasticsearch"

  it "disables other instrumentation" do
    client.indices.create(index: "skylight-test")

    # Should disable other HTTP instrumentation
    expect(current_trace.mock_spans).to_not include(
      a_hash_including(
        cat: "api.http.put"
      )
    )
  end

  context "with unininitialized probe dependencies" do
    before do
      # Pretend the probes aren't installed
      expect(::ActiveSupport::Inflector).to receive(:safe_constantize).
        with("Skylight::Probes::NetHTTP::Probe").at_least(:once).and_return(nil)
      expect(::ActiveSupport::Inflector).to receive(:safe_constantize).
        with("Skylight::Probes::HTTPClient::Probe").at_least(:once).and_return(nil)
    end

    it_behaves_like "instrumented elasticsearch"
  end
end
