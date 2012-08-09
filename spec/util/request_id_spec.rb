require 'spec_helper'

module Tilde
  describe Util do

    let :request_id_format do
      /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/
    end

    context ".generate_request_id" do

      it "returns a random request ID" do
        Util.generate_request_id.should =~ request_id_format
      end

      it "returns different request IDs each time" do
        (1..100).map { Util.generate_request_id }.uniq.size.should == 100
      end

    end

  end
end
