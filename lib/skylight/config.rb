require 'yaml'

module Skylight
  class Config

    def self.load_from_yaml(path)
      new do |config|
        data = YAML.load_file(path)
        data.each do |key, value|
          config.send("#{key}=", value)
        end
      end
    end

    def initialize
      @authentication_token = "8yagFhG61tYeY4j18K8+VpI0CyG4sht5J2Oj7RQL05RhcHBsaWNhdGlvbl9pZHM9Zm9vJnJvbGU9YWdlbnQ="
      @ssl = true
      @deflate = true
      @host = "agent.skylight.io"
      @port = 443
      @samples_per_interval = 100
      @interval = 5
      @max_pending_traces = 1_000

      yield self if block_given?
    end

    attr_accessor :authentication_token

    attr_accessor :ssl
    alias_method :ssl?, :ssl

    attr_accessor :deflate
    alias_method :deflate?, :deflate

    attr_accessor :host

    attr_accessor :port

    attr_accessor :samples_per_interval

    attr_accessor :interval

    attr_accessor :max_pending_traces

  end
end
