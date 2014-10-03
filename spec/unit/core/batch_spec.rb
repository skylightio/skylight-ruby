require 'spec_helper'

module Skylight
  describe 'Batch', :agent do
    it 'serializes counts' do
      batch = Batch.native_new(0, "localhost")
      batch.native_set_endpoint_count "foo", 3

      actual = SpecHelper::Messages::Batch.decode(batch.native_serialize)
      actual.endpoints.count.should == 1

      endpoint = actual.endpoints[0]
      endpoint.name.should == "foo"
      endpoint.count.should == 3
      endpoint.traces.should be_nil
    end
  end
end
