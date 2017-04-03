require 'yaml'
require 'fileutils'
require 'thread'
require 'openssl'
require 'erb'
require 'json'
require 'skylight/util/deploy'
require 'skylight/util/hostname'
require 'skylight/util/logging'
require 'skylight/util/platform'
require 'skylight/util/ssl'
require 'skylight/util/proxy'

module Skylight
  class Config
    include Util::Logging

    # @api private
    MUTEX = Mutex.new

    # Map environment variable keys with Skylight configuration keys
    ENV_TO_KEY = {
      # == Authentication ==
      'AUTHENTICATION' => :authentication,

      # == App settings ==
      'ROOT'          => :root,
      'HOSTNAME'      => :hostname,
      'SESSION_TOKEN' => :session_token,

      # == Deploy settings ==
      'DEPLOY_ID'          => :'deploy.id',
      'DEPLOY_GIT_SHA'     => :'deploy.git_sha',
      'DEPLOY_DESCRIPTION' => :'deploy.description',

      # == Logging ==
      'LOG_FILE'       => :log_file,
      'LOG_LEVEL'      => :log_level,
      'ALERT_LOG_FILE' => :alert_log_file,
      'LOG_SQL_PARSE_ERRORS' => :log_sql_parse_errors,

      # == Proxy ==
      'PROXY_URL' => :proxy_url,

      # == Instrumenter ==
      "IGNORED_ENDPOINT" => :ignored_endpoint,
      "IGNORED_ENDPOINTS" => :ignored_endpoints,
      "ENABLE_SEGMENTS" => :enable_segments,

      # == Skylight Remote ==
      "AUTH_URL"                     => :auth_url,
      "APP_CREATE_URL"               => :app_create_url,
      "VALIDATION_URL"               => :validation_url,
      "AUTH_HTTP_DEFLATE"            => :auth_http_deflate,
      "AUTH_HTTP_CONNECT_TIMEOUT"    => :auth_http_connect_timeout,
      "AUTH_HTTP_READ_TIMEOUT"       => :auth_http_read_timeout,
      "REPORT_URL"                   => :report_url,
      "REPORT_HTTP_DEFLATE"          => :report_http_deflate,
      "REPORT_HTTP_CONNECT_TIMEOUT"  => :report_http_connect_timeout,
      "REPORT_HTTP_READ_TIMEOUT"     => :report_http_read_timeout,

      # == Native agent settings ==
      #
      "LAZY_START"                   => :'daemon.lazy_start',
      "DAEMON_EXEC_PATH"             => :'daemon.exec_path',
      "DAEMON_LIB_PATH"              => :'daemon.lib_path',
      "PIDFILE_PATH"                 => :'daemon.pidfile_path',
      "SOCKDIR_PATH"                 => :'daemon.sockdir_path',
      "BATCH_QUEUE_DEPTH"            => :'daemon.batch_queue_depth',
      "BATCH_SAMPLE_SIZE"            => :'daemon.batch_sample_size',
      "BATCH_FLUSH_INTERVAL"         => :'daemon.batch_flush_interval',
      "DAEMON_TICK_INTERVAL"         => :'daemon.tick_interval',
      "DAEMON_SANITY_CHECK_INTERVAL" => :'daemon.sanity_check_interval',
      "DAEMON_INACTIVITY_TIMEOUT"    => :'daemon.inactivity_timeout',
      "CLIENT_MAX_TRIES"             => :'daemon.max_connect_tries',
      "CLIENT_CONN_TRY_WIN"          => :'daemon.connect_try_window',
      "MAX_PRESPAWN_JITTER"          => :'daemon.max_prespawn_jitter',
      "DAEMON_WAIT_TIMEOUT"          => :'daemon.wait_timeout',
      "CLIENT_CHECK_INTERVAL"        => :'daemon.client_check_interval',
      "CLIENT_QUEUE_DEPTH"           => :'daemon.client_queue_depth',
      "CLIENT_WRITE_TIMEOUT"         => :'daemon.client_write_timeout',
      "SSL_CERT_PATH"                => :'daemon.ssl_cert_path',
      "SSL_CERT_DIR"                 => :'daemon.ssl_cert_dir',

      # == Heroku settings ==
      #
      "HEROKU_DYNO_INFO_PATH"        => :'heroku.dyno_info_path',

      # == Legacy env vars ==
      #
      'AGENT_LOCKFILE'      => :'agent.lockfile',
      'AGENT_SOCKFILE_PATH' => :'agent.sockfile_path'
    }

    # Default values for Skylight configuration keys
    DEFAULTS = {
      :auth_url             => 'https://auth.skylight.io/agent',
      :app_create_url       => 'https://www.skylight.io/apps',
      :validation_url       => 'https://auth.skylight.io/agent/config',
      :'daemon.lazy_start'  => true,
      :log_file             => '-'.freeze,
      :log_level            => 'INFO'.freeze,
      :alert_log_file       => '-'.freeze,
      :log_sql_parse_errors => false,
      :enable_segments      => true,
      :hostname             => Util::Hostname.default_hostname,
      :'heroku.dyno_info_path' => '/etc/heroku/dyno'
    }

    if Skylight::Util::Platform::OS != 'darwin'
      DEFAULTS[:'daemon.ssl_cert_path'] = Util::SSL.ca_cert_file_or_default
      DEFAULTS[:'daemon.ssl_cert_dir'] = Util::SSL.ca_cert_dir
    end

    if Skylight.native?
      native_path = Skylight.libskylight_path

      DEFAULTS[:'daemon.lib_path'] = native_path
      DEFAULTS[:'daemon.exec_path'] = File.join(native_path, 'skylightd')
    end

    DEFAULTS.freeze

    REQUIRED = {
      authentication: "authentication token",
      hostname:       "server hostname",
      auth_url:       "authentication url",
      validation_url: "config validation url" }

    SERVER_VALIDATE = [
      # Nothing is validated for now, but this is a list of symbols
      # for the key we want to validate.
    ]

    NATIVE_ENV = [
      :version,
      :root,
      :hostname,
      :deploy_id,
      :session_token,
      :proxy_url,
      :auth_url,
      :auth_http_deflate,
      :auth_http_connect_timeout,
      :auth_http_read_timeout,
      :report_url,
      :report_http_deflate,
      :report_http_connect_timeout,
      :report_http_read_timeout,
      :'daemon.lazy_start',
      :'daemon.exec_path',
      :'daemon.lib_path',
      :'daemon.pidfile_path',
      :'daemon.sockdir_path',
      :'daemon.batch_queue_depth',
      :'daemon.batch_sample_size',
      :'daemon.batch_flush_interval',
      :'daemon.tick_interval',
      :'daemon.sanity_check_interval',
      :'daemon.inactivity_timeout',
      :'daemon.max_connect_tries',
      :'daemon.connect_try_window',
      :'daemon.max_prespawn_jitter',
      :'daemon.wait_timeout',
      :'daemon.client_check_interval',
      :'daemon.client_queue_depth',
      :'daemon.client_write_timeout',
      :'daemon.ssl_cert_path',
      :'daemon.ssl_cert_dir'
    ]

    # Maps legacy config keys to new config keys
    LEGACY = {
      :'agent.sockfile_path' => :'daemon.sockdir_path',
      :'agent.lockfile'  => :'daemon.pidfile_path'
    }

    VALIDATORS = {
      :'agent.interval' => [lambda { |v, c| Integer === v && v > 0 }, "must be an integer greater than 0"]
    }

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
          @priority[Config.remap_key(k)] = v
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
      LEGACY[key] || key
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
        # Support deprecated SK_ key prefix
        next unless k =~ /^(?:SK|SKYLIGHT)_(.+)$/

        if key = ENV_TO_KEY[$1]
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

    def api
      @api ||= Api.new(self)
    end

    # @api private
    def validate!
      REQUIRED.each do |k, v|
        unless get(k)
          raise ConfigError, "#{v} required"
        end
      end

      # TODO: Move this out of the validate! method: https://github.com/tildeio/direwolf-agent/issues/273
      # FIXME: Why not set the sockdir_path and pidfile_path explicitly?
      # That way we don't have to keep this in sync with the Rust repo.
      sockdir_path = File.expand_path(self[:'daemon.sockdir_path'] || '.', root)
      pidfile_path = File.expand_path(self[:'daemon.pidfile_path'] || 'skylight.pid', sockdir_path)
      log_file = self[:log_file]
      alert_log_file = self[:alert_log_file]

      check_file_permissions(pidfile_path, "daemon.pidfile_path or daemon.sockdir_path")
      check_sockdir_permissions(sockdir_path)
      check_logfile_permissions(log_file, "log_file")
      check_logfile_permissions(alert_log_file, "alert_log_file")

      true
    end

    def validate_with_server
      res = api.validate_config

      unless res.token_valid?
        warn("Invalid authentication token")
        return false
      end

      if res.is_error_response?
        warn("Unable to reach server for config validation")
      end

      unless res.config_valid?
        warn("Invalid configuration") unless res.is_error_response?
        if errors = res.validation_errors
          errors.each do |k,v|
            warn("  #{k} #{v}")
          end
        end

        corrected_config = res.corrected_config
        unless corrected_config
          # Use defaults if no corrected config is available. This will happen if the request failed.
          corrected_config = Hash[SERVER_VALIDATE.map{|k| [k, DEFAULTS[k]] }]
        end

        config_to_update = corrected_config.select{|k,v| get(k) != v }
        unless config_to_update.empty?
          info("Updating config values:")
          config_to_update.each do |k,v|
            info("  setting #{k} to #{v}")

            # This is a weird way to handle priorities
            # See https://github.com/tildeio/direwolf-agent/issues/275
            k = "#{environment}.#{k}" if environment

            set(k, v)
          end
        end
      end

      return true
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

    def check_sockdir_permissions(sockdir_path)
      # Try to make the directory, don't blow up if we can't. Our writable? check will fail later.
      FileUtils.mkdir_p sockdir_path rescue nil

      unless FileTest.writable?(sockdir_path)
        raise ConfigError, "Directory `#{sockdir_path}` is not writable. Please set daemon.sockdir_path in your config to a writable path"
      end

      if check_nfs(sockdir_path)
        raise ConfigError, "Directory `#{sockdir_path}` is an NFS mount and will not allow sockets. Please set daemon.sockdir_path in your config to a non-NFS path."
      end
    end

    def check_logfile_permissions(log_file, key)
      return if log_file == '-' # STDOUT
      log_file = File.expand_path(log_file, root)
      check_file_permissions(log_file, key)
    end

    def key?(key)
      key = Config.remap_key(key)
      @priority.key?(key) || @values.key?(key)
    end

    def get(key, default = nil, &blk)
      key = Config.remap_key(key)

      return @priority[key] if @priority.key?(key)
      return @values[key]   if @values.key?(key)
      return DEFAULTS[key]  if DEFAULTS.key?(key)

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
        k = Config.remap_key(key)

        if validator = VALIDATORS[k]
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

      ret << "SKYLIGHT_AUTHENTICATION" << authentication_with_deploy

      NATIVE_ENV.each do |key|
        value = send_or_get(key)
        unless value.nil?
          env_key = ENV_TO_KEY.key(key) || key.upcase
          ret << "SKYLIGHT_#{env_key}" << cast_for_env(value)
        end
      end

      ret << "SKYLIGHT_VALIDATE_AUTHENTICATION" << "false"

      ret
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))

      File.open(path, 'w') do |f|
        f.puts <<-YAML
---
# The authentication token for the application.
authentication: #{self[:authentication]}
        YAML
      end
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
    def ignore_token?
      get('test.ignore_token')
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

    def authentication_with_deploy
      token = get(:authentication)

      if token && deploy
        deploy_str = deploy.to_query_string
        # A pipe should be a safe delimiter since it's not in the standard token
        # and is encoded by URI
        token += "|#{deploy_str}"
      end

      token
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

    def on_heroku?
      File.exist?(get(:'heroku.dyno_info_path'))
    end

    def deploy
      @deploy ||= Util::Deploy.build(self)
    end

    def enable_segments?
      !!get(:enable_segments)
    end

  private

    def check_nfs(path)
      # Should work on most *nix, though not on OS X
      `stat -f -L -c %T #{path} 2>&1`.strip == 'nfs'
    end

    def create_logger(out)
      if out.is_a?(String)
        out = File.expand_path(out, root)
        # May be redundant since we also do this in the permissions check
        FileUtils.mkdir_p(File.dirname(out))
      end

      Logger.new(out)
    rescue
      Logger.new(STDOUT)
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
