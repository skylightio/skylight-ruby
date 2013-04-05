require 'spec_helper'

module Skylight
  describe Middleware do
    include Rack::Test::Methods

    def app
      @app
    end

    def instrumenter_class(instrumenter)
      config = config_object

      Class.new do
        @instrumenter = instrumenter
        @config = config

        def self.start!(cfg)
          cfg.should == @config
          @instrumenter
        end
      end
    end

    def config_object
      @config_object ||= Config.new authentication_token: "foobarbaz"
    end

    def build_app(klass)
      config = config_object

      @app = Rack::Builder.new do
        use Middleware, config, klass
        run lambda{|env| [200, {'Content-Type' => 'text/plain'}, ["Hello world!"]]}
      end
    end

    it "calls the instrumenter and passes through" do
      instrumenter = Object.new
      build_app(instrumenter_class(instrumenter))

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

      build_app(instrumenter_class)

      get '/'

      last_response.should be_ok
      last_response.body.should == 'Hello world!'
    end
  end
end
