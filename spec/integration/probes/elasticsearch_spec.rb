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

    it "handles uninitialized probe dependencies" do
      # Temporarily uninstall NetHTTP and HTTPClient probes
      TempNetHTTPProbe    = Skylight::Probes::NetHTTP::Probe
      TempHTTPClientProbe = Skylight::Probes::HTTPClient::Probe
      Skylight::Probes::NetHTTP.send(:remove_const, :Probe)
      Skylight::Probes::HTTPClient.send(:remove_const, :Probe)
      allow_any_instance_of(::Net::HTTP).to receive(:request){|obj, *args| obj.send(:request_without_sk, *args)}
      allow_any_instance_of(::HTTPClient).to receive(:do_request){|obj, *args| obj.send(:do_request_without_sk, *args)}

      expect(current_trace).to receive(:instrument).with("db.elasticsearch.request", "PUT skylight-test", nil).and_call_original.once
      client.indices.create(index: 'skylight-test')

      expect(current_trace).to receive(:instrument).with("db.elasticsearch.request", "PUT skylight-test", {type: 'person', id: '?'}.to_json).and_call_original.once
      client.index(index: 'skylight-test', type: 'person', id: '1', body: {name: 'Joe'})

      # Restore NetHTTP and HTTPClient probe constants
      Skylight::Probes::NetHTTP::Probe    = TempNetHTTPProbe
      Skylight::Probes::HTTPClient::Probe = TempHTTPClientProbe
      Object.send(:remove_const, :'TempNetHTTPProbe')
      Object.send(:remove_const, :'TempHTTPClientProbe')
    end
  end
end
