require 'spec_helper'

module Skylight
  describe Middleware do
    include Rack::Test::Methods

    let :config do
      Config.new authentication_token: "foobarbaz"
    end

    def app
      @app
    end

    it "calls the instrumenter and passes through" do
      instrumenter = Object.new

      instrumenter_class = Class.new do
        @instrumenter = instrumenter

        def self.start!(*)
          @instrumenter
        end
      end

      c = config

      @app = Rack::Builder.new do
        use Middleware, c, instrumenter_class
        run lambda{|env| [200, {'Content-Type' => 'text/plain'}, ["Hello world!"]]}
      end

      instrumenter.should_receive(:trace).with("Rack").and_yield

      get '/'

      last_response.should be_ok
      last_response.body.should == 'Hello world!'
    end

    it "uses a stub middleware if starting the instrumenter throws an exception" do
      instrumenter_class = Class.new do
        def self.start!(*)
          raise "FAIL"
        end
      end

      c = config

      @app = Rack::Builder.new do
        use Middleware, c, instrumenter_class
        run lambda{|env| [200, {'Content-Type' => 'text/plain'}, ["Hello world!"]]}
      end

      get '/'

      last_response.should be_ok
      last_response.body.should == 'Hello world!'
    end
  end
end
