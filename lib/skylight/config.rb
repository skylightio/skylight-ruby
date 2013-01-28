require 'yaml'

module Skylight
  class Config

    def self.load_from_yaml(path)
      new do |config|
        data = YAML.load_file(path)
        data.each do |key, value|
          if config.respond_to?("#{key}=")
            config.send("#{key}=", value)
          end
        end
      end
    end

    def initialize
      @ssl      = true
      @deflate  = true
      @host     = "agent.skylight.io"
      @port     = 443
      @interval = 5
      @protocol = JsonProto.new(self)
      @max_pending_traces = 500
      @samples_per_interval = 100

      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

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

    attr_reader :protocol
    def protocol=(val)
      if val.is_a?(String) || val.is_a?(Symbol)
        class_name = val.to_s.capitalize+"Proto"
        val = Skylight.const_get(class_name).new(self)
      end
      @protocol = val
    end

    attr_accessor :logger

    def log_level
      logger && logger.level
    end

    def log_level=(level)
      if logger
        if level.is_a?(String) || level.is_a?(Symbol)
          level = Logger.const_get(level.to_s.upcase)
        end
        logger.level = level
      end
    end

  end
end
