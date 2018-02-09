require 'yaml'
require 'fileutils'
require 'thread'
require 'erb'
require 'json'
require 'skylight/core/util/logging'
require 'skylight/core/util/proxy'
require 'skylight/core/errors'

module Skylight::Core
  class Config
    include Util::Logging

    # @api private
    MUTEX = Mutex.new

    def self.log_name; "Skylight" end
    def self.env_matcher; /^(?:SK|SKYLIGHT)_(.+)$/ end
    def self.env_prefix; "SKYLIGHT_" end

    # Map environment variable keys with Skylight configuration keys
    def self.env_to_key
      {
        # == Logging ==
        'LOG_FILE'       => :log_file,
        'LOG_LEVEL'      => :log_level,
        'ALERT_LOG_FILE' => :alert_log_file,
        'LOG_SQL_PARSE_ERRORS' => :log_sql_parse_errors,

        # == Proxy ==
        'PROXY_URL' => :proxy_url,

        # == Instrumenter ==
        "ENABLE_SEGMENTS" => :enable_segments,

        # == User config settings ==
        "USER_CONFIG_PATH" => :'user_config_path',

        # == Heroku settings ==
        #
        "HEROKU_DYNO_INFO_PATH" => :'heroku.dyno_info_path'
      }
    end

    # Default values for Skylight configuration keys
    def self.default_values
      {
        :log_file             => '-'.freeze,
        :log_level            => 'INFO'.freeze,
        :alert_log_file       => '-'.freeze,
        :log_sql_parse_errors => false,
        :enable_segments      => true,
        :'heroku.dyno_info_path' => '/etc/heroku/dyno'
      }
    end

    def self.required_keys
      # Nothing is required in this base class.
      {}
    end

    def self.server_validated_keys
      # Nothing is validated for now, but this is a list of symbols
      # for the key we want to validate.
      []
    end

    def self.native_env_keys
      [
        :version,
        :root,
        :proxy_url
      ]
    end

    # Maps legacy config keys to new config keys
    def self.legacy_keys
      # No legacy keys for now
      {}
    end

    def self.validators
      # None for now
      {}
    end

    # @api private
    attr_reader :environment

    # @api private
    def initialize(*args)
      attrs = {}

      if Hash === args.last
        attrs = args.pop.dup
      end

      @values   = {}
      @priority = {}
      @regexp   = nil

      p = attrs.delete(:priority)

      if @environment = args[0]
        @regexp = /^#{Regexp.escape(@environment)}\.(.+)$/
      end

      attrs.each do |k, v|
        self[k] = v
      end

      if p
        p.each do |k, v|
          @priority[self.class.remap_key(k)] = v
        end
      end
    end

    def self.load(opts = {}, env = ENV)
      attrs   = {}
      version = nil

      path = opts.delete(:file)
      environment = opts.delete(:environment)

      if path
        error = nil
        begin
          attrs = YAML.load(ERB.new(File.read(path)).result)
          error = "empty file" unless attrs
          error = "invalid format" if attrs && !attrs.is_a?(Hash)
        rescue Exception => e
          error = e.message
        end

        raise ConfigError, "could not load config file; msg=#{error}" if error

        version = File.mtime(path).to_i
      end

      if env
        attrs[:priority] = remap_env(env)
      end

      config = new(environment, attrs)

      opts.each do |k, v|
        config[k] = v
      end

      config
    end

    def self.remap_key(key)
      key = key.to_sym
      legacy_keys[key] || key
    end

    # @api private
    def self.remap_env(env)
      ret = {}

      return ret unless env

      # Only set if it exists, we don't want to set to a nil value
      if proxy_url = Util::Proxy.detect_url(env)
        ret[:proxy_url] = proxy_url
      end

      env.each do |k, val|
        next unless k =~ env_matcher

        if key = env_to_key[$1]
          ret[key] =
            case val
            when /^false$/i      then false
            when /^true$/i       then true
            when /^(nil|null)$/i then nil
            when /^\d+$/         then val.to_i
            when /^\d+\.\d+$/    then val.to_f
            else val
            end
        end
      end

      ret
    end

    # @api private
    def validate!
      self.class.required_keys.each do |k, v|
        unless get(k)
          raise ConfigError, "#{v} required"
        end
      end

      log_file = self[:log_file]
      alert_log_file = self[:alert_log_file]

      check_logfile_permissions(log_file, "log_file")
      check_logfile_permissions(alert_log_file, "alert_log_file")

      true
    end

    def validate_with_server
      true
    end

    def check_file_permissions(file, key)
      file_root = File.dirname(file)

      # Try to make the directory, don't blow up if we can't. Our writable? check will fail later.
      FileUtils.mkdir_p file_root rescue nil

      if File.exist?(file) && !FileTest.writable?(file)
        raise ConfigError, "File `#{file}` is not writable. Please set #{key} in your config to a writable path"
      end

      unless FileTest.writable?(file_root)
        raise ConfigError, "Directory `#{file_root}` is not writable. Please set #{key} in your config to a writable path"
      end
    end

    def check_logfile_permissions(log_file, key)
      return if log_file == '-' # STDOUT
      log_file = File.expand_path(log_file, root)
      check_file_permissions(log_file, key)
    end

    def key?(key)
      key = self.class.remap_key(key)
      @priority.key?(key) || @values.key?(key)
    end

    def get(key, default = nil, &blk)
      key = self.class.remap_key(key)

      return @priority[key] if @priority.key?(key)
      return @values[key]   if @values.key?(key)
      return self.class.default_values[key] if self.class.default_values.key?(key)

      if default
        return default
      elsif blk
        return blk.call(key)
      end

      nil
    end

    alias [] get

    def set(key, val, scope = nil)
      if scope
        key = [scope, key].join('.')
      end

      if Hash === val
        val.each do |k, v|
          set(k, v, key)
        end
      else
        k = self.class.remap_key(key)

        if validator = self.class.validators[k]
          blk, msg = validator

          unless blk.call(val, self)
            error_msg = "invalid value for #{k} (#{val})"
            error_msg << ", #{msg}" if msg
            raise ConfigError, error_msg
          end
        end

        if @regexp && k =~ @regexp
          @priority[$1.to_sym] = val
        end

        @values[k] = val
      end
    end

    alias []= set

    def send_or_get(v)
      respond_to?(v) ? send(v) : get(v)
    end

    def duration_ms(key, default = nil)
      if (v = self[key]) && v.to_s =~ /^\s*(\d+)(s|sec|ms|micros|nanos)?\s*$/
        v = $1.to_i
        case $2
        when "ms"
          v
        when "micros"
          v / 1_000
        when "nanos"
          v / 1_000_000
        else # "s", "sec", nil
          v * 1000
        end
      else
        default
      end
    end

    def to_json
      JSON.generate(
        config: {
          priority: @priority,
          values:   @values
        }
      )
    end

    def to_native_env
      ret = []

      self.class.native_env_keys.each do |key|
        value = send_or_get(key)
        unless value.nil?
          env_key = self.class.env_to_key.key(key) || key.upcase
          ret << "#{self.class.env_prefix}#{env_key}" << cast_for_env(value)
        end
      end

      ret
    end

    def write(path)
      raise "not implemented"
    end

    #
    #
    # ===== Helpers =====
    #
    #

    def version
      VERSION
    end

    # @api private
    def gc
      @gc ||= GC.new(self, get('gc.profiler', VM::GC.new))
    end

    # @api private
    def ignored_endpoints
      @ignored_endpoints ||=
        begin
          ignored_endpoints = get(:ignored_endpoints)

          # If, for some odd reason you have a comma in your endpoint name, use the
          # YML config instead.
          if ignored_endpoints.is_a?(String)
            ignored_endpoints = ignored_endpoints.split(/\s*,\s*/)
          end

          val = Array(get(:ignored_endpoint))
          val.concat(Array(ignored_endpoints))
          val
        end
    end

    def root
      self[:root] || Dir.pwd
    end

    def logger
      @logger ||=
        MUTEX.synchronize do
          load_logger
        end
    end

    def logger=(logger)
      @logger = logger
    end

    def alert_logger
      @alert_logger ||= MUTEX.synchronize do
        unless l = @alert_logger
          out = get(:alert_log_file)
          out = Util::AlertLogger.new(load_logger) if out == '-'

          l = create_logger(out)
          l.level = Logger::DEBUG
        end

        l
      end
    end

    def alert_logger=(logger)
      @alert_logger = logger
    end

    def enable_segments?
      !!get(:enable_segments)
    end

    def user_config
      @user_config ||= UserConfig.new(self)
    end

    def on_heroku?
      File.exist?(get(:'heroku.dyno_info_path'))
    end

  private

    def create_logger(out)
      l = begin
        if out.is_a?(String)
          out = File.expand_path(out, root)
          # May be redundant since we also do this in the permissions check
          FileUtils.mkdir_p(File.dirname(out))
        end

        Logger.new(out)
      rescue
        Logger.new(STDOUT)
      end
      l.progname = self.class.log_name
      l
    end

    def load_logger
      unless l = @logger
        out = get(:log_file)
        out = STDOUT if out == '-'

        l = create_logger(out)
        l.level =
          case get(:log_level)
          when /^debug$/i then Logger::DEBUG
          when /^info$/i  then Logger::INFO
          when /^warn$/i  then Logger::WARN
          when /^error$/i then Logger::ERROR
          end
      end

      l
    end

    def cast_for_env(v)
      case v
      when true  then 'true'
      when false then 'false'
      when nil   then 'nil'
      else v.to_s
      end
    end

  end
end
