require 'yaml'
require 'logger'
require 'fileutils'

module Skylight
  class Config
    class Normalizer < Struct.new(:view_paths)
    end

    class << self
      def load_from_yaml(path, env=ENV)
        new do |config|
          data = YAML.load_file(path)

          data.each do |key, value|
            apply_config(config, key, value)
          end

          config.yaml_file = path

          apply_env(config, env)
        end
      end

      def load_from_env(opts={}, env=ENV)
        new(opts) do |config|
          apply_env(config, env)
        end
      end

    private

      def apply_env(config, env)
        env.each do |key, value|
          name = normalize_env(key)
          apply_config(config, name, value) if name
        end
      end

      def normalize_env(key)
        match = key.match(/^SKYLIGHT_(\w+)$/)
        match && match[1].downcase
      end

      def apply_config(config, key, value)
        config.send("#{key}=", value) if config.respond_to?("#{key}=")
      end
    end

    def initialize(attrs = {})
      @ssl      = true
      @deflate  = true
      @host     = "agent.skylight.io"
      @port     = 443
      @interval = 5
      @protocol = JsonProto.new(self)
      @max_pending_traces   = 500
      @samples_per_interval = 100

      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

      @normalizer = Normalizer.new

      attrs.each do |k, v|
        if respond_to?("#{k}=")
          send("#{k}=", v)
        end
      end

      @http ||= Util::HTTP.new(self)
      @gc_profiler ||= GC::Profiler

      yield self if block_given?
    end

    attr_accessor :yaml_file
    attr_accessor :authentication_token
    attr_accessor :app_id

    attr_accessor :ssl
    alias_method :ssl?, :ssl

    attr_accessor :deflate
    alias_method :deflate?, :deflate

    attr_accessor :host

    attr_accessor :port

    attr_accessor :http

    attr_accessor :samples_per_interval

    attr_accessor :interval

    attr_accessor :max_pending_traces

    attr_reader :normalizer

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

    attr_writer :gc_profiler

    def gc_profiler
      # TODO: Move this into tests
      @gc_profiler ||= Struct.new(:enable, :disable, :clear, :total_time).new(nil, nil, nil, 0)
    end

    def save(filename=yaml_file)
      FileUtils.mkdir_p File.dirname(filename)

      File.open(filename, "w") do |file|
        config = {}
        config["authentication_token"] = authentication_token if authentication_token
        config["app_id"] = app_id if app_id
        file.puts YAML.dump(config)
      end
    end
  end
end
