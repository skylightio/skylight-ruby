require 'spec_helper'

module Skylight::Util
  describe HTTP do

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
        stub_request(:get, "https://agent.skylight.io/foobar").
          to_return(:status => 200, :body => "", :headers => {})
      end

      it "gets details from config" do
        config[:'report.proxy_addr'] = "example.com"
        config[:'report.proxy_port'] = 1234
        config[:'report.proxy_user'] = 'test'
        config[:'report.proxy_pass'] = 'pass'

        http = HTTP.new(config)

        Net::HTTP.should_receive(:new).with("agent.skylight.io", 443, "example.com", 1234, "test", "pass").and_call_original

        http.get("/foobar")
      end

      it "gets details from HTTP_PROXY" do
        ENV['HTTP_PROXY'] = "http://testing:otherpass@proxy.example.com:4321"

        http = HTTP.new(config)

        Net::HTTP.should_receive(:new).with("agent.skylight.io", 443, "proxy.example.com", 4321, "testing", "otherpass").and_call_original

        http.get("/foobar")
      end

      it "gives priority to config" do
        config[:'report.proxy_addr'] = "example.com"
        config[:'report.proxy_port'] = 1234
        config[:'report.proxy_user'] = 'test'
        config[:'report.proxy_pass'] = 'pass'

        ENV['HTTP_PROXY'] = "http://testing:otherpass@proxy.example.com:4321"

        http = HTTP.new(config)

        Net::HTTP.should_receive(:new).with("agent.skylight.io", 443, "example.com", 1234, "test", "pass").and_call_original

        http.get("/foobar")
      end

    end

  end
end