require 'spec_helper'

# Requires elasticsearch instance to be running
if ENV['TEST_ELASTICSEARCH_INTEGRATION']
  describe 'Elasticsearch integration', :elasticsearch_probe, :instrumenter do

    let(:client) do
      Elasticsearch::Client.new
    end

    before do
      # Delete index if it exists
      Skylight.disable do
        client.indices.delete(index: 'skylight-test') rescue nil
      end
    end

    it "instruments without affecting default instrumenter" do
      expect(current_trace).to receive(:instrument).with("db.elasticsearch.request", "PUT skylight-test", nil).and_call_original.once
      client.indices.create(index: 'skylight-test')

      expect(current_trace).to receive(:instrument).with("db.elasticsearch.request", "PUT skylight-test", {type: 'person', id: '?'}.to_json).and_call_original.once
      client.index(index: 'skylight-test', type: 'person', id: '1', body: {name: 'Joe'})
    end
  end
end
