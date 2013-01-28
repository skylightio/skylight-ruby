require 'spec_helper'

module Skylight
  describe Middleware do
    include Rack::Test::Methods

    let :instrumenter do
      Instrumenter.start! authentication_token: "foobarbaz"
    end

    let :app do
      ins = instrumenter

      Rack::Builder.new do
        use Middleware, ins
        run lambda{|env| [200, {'Content-Type' => 'text/plain'}, ["Hello world!"]]}
      end
    end

    it "calls the instrumenter and passes through" do
      instrumenter.should_receive(:trace).with("Rack").and_yield

      get '/'

      last_response.should be_ok
      last_response.body.should == 'Hello world!'
    end
  end
end
