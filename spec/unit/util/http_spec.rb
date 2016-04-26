require 'spec_helper'

module Skylight
  describe Util::HTTP do

    let :config do
      Skylight::Config.new
    end

    before :each do
      # We use WebMock here to prevent actual requests from being made
      WebMock.enable!
      @original_env = ENV.to_hash
    end

    after :each do
      ENV.replace(@original_env)
      WebMock.disable!
    end

    describe "proxy" do

      before :each do
        stub_request(:get, "https://auth.skylight.io/foobar").
          to_return(:status => 200, :body => "", :headers => {})
      end

      it "gets details from config" do
        config[:proxy_url] = "http://test:pass@example.com:1234"

        http = Util::HTTP.new(config)

        expect(Net::HTTP).to receive(:new).with("auth.skylight.io", 443, "example.com", 1234, "test", "pass").and_call_original

        http.get("/foobar")
      end

      it "gets details from HTTP_PROXY" do
        http = Util::HTTP.new(Config.load({},
          'HTTP_PROXY' => "http://testing:otherpass@proxy.example.com:4321"))

        expect(Net::HTTP).to receive(:new).
          with("auth.skylight.io", 443, "proxy.example.com", 4321, "testing", "otherpass").
          and_call_original

        http.get("/foobar")
      end
    end
  end
end
