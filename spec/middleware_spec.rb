require 'spec_helper'

module Skylight
  describe Middleware do
    include Rack::Test::Methods

    let :config do
      Config.new authentication_token: "foobarbaz"
    end

    let :instrumenter do
      Object.new
    end

    let :app do
      # Pull into local variables so they're usable in the Rack::Builder
      # block, which is instance_evalled.
      c, i = config, instrumenter

      Rack::Builder.new do
        use Middleware, c, i
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
