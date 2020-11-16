require "openssl"
require "yaml"
require "fileutils"
require "erb"
require "json"
require "skylight/util/logging"
require "skylight/util/proxy"
require "skylight/errors"
require "skylight/util/component"
require "skylight/util/deploy"
require "skylight/util/platform"
require "skylight/util/hostname"
require "skylight/util/ssl"

module Skylight
  class Config
    include Util::Logging

    # @api private
    MUTEX = Mutex.new

    # Map environment variable keys with Skylight configuration keys
    ENV_TO_KEY = {
      # == Authentication ==
      -"AUTHENTICATION"               => :authentication,

      # == App settings ==
      -"ROOT"                         => :root,
      -"HOSTNAME"                     => :hostname,
      -"SESSION_TOKEN"                => :session_token,

      # == Component settings ==
      -"ENV"                          => :env,
      -"COMPONENT"                    => :component,
      -"REPORT_RAILS_ENV"             => :report_rails_env,

      # == Deploy settings ==
      -"DEPLOY_ID"                    => :'deploy.id',
      -"DEPLOY_GIT_SHA"               => :'deploy.git_sha',
      -"DEPLOY_DESCRIPTION"           => :'deploy.description',

      # == Logging ==
      -"LOG_FILE"                     => :log_file,
      -"LOG_LEVEL"                    => :log_level,
      -"ALERT_LOG_FILE"               => :alert_log_file,
      -"NATIVE_LOG_FILE"              => :native_log_file,
      -"LOG_SQL_PARSE_ERRORS"         => :log_sql_parse_errors,

      # == Proxy ==
      -"PROXY_URL"                    => :proxy_url,

      # == Instrumenter ==
      -"ENABLE_SEGMENTS"              => :enable_segments,
      -"ENABLE_SIDEKIQ"               => :enable_sidekiq,
      -"IGNORED_ENDPOINT"             => :ignored_endpoint,
      -"IGNORED_ENDPOINTS"            => :ignored_endpoints,
      -"SINATRA_ROUTE_PREFIXES"       => :sinatra_route_prefixes,
      -"ENABLE_SOURCE_LOCATIONS"      => :enable_source_locations,

      # == Max Span Handling ==
      -"REPORT_MAX_SPANS_EXCEEDED"    => :report_max_spans_exceeded,
      -"PRUNE_LARGE_TRACES"           => :prune_large_traces,

      # == Skylight Remote ==
      -"AUTH_URL"                     => :auth_url,
      -"APP_CREATE_URL"               => :app_create_url,
      -"MERGES_URL"                   => :merges_url,
      -"VALIDATION_URL"               => :validation_url,
      -"AUTH_HTTP_DEFLATE"            => :auth_http_deflate,
      -"AUTH_HTTP_CONNECT_TIMEOUT"    => :auth_http_connect_timeout,
      -"AUTH_HTTP_READ_TIMEOUT"       => :auth_http_read_timeout,
      -"REPORT_URL"                   => :report_url,
      -"REPORT_HTTP_DEFLATE"          => :report_http_deflate,
      -"REPORT_HTTP_CONNECT_TIMEOUT"  => :report_http_connect_timeout,
      -"REPORT_HTTP_READ_TIMEOUT"     => :report_http_read_timeout,
      -"REPORT_HTTP_DISABLED"         => :report_http_disabled,

      # == Native agent settings ==
      #
      -"LAZY_START"                   => :'daemon.lazy_start',
      -"DAEMON_EXEC_PATH"             => :'daemon.exec_path',
      -"DAEMON_LIB_PATH"              => :'daemon.lib_path',
      -"PIDFILE_PATH"                 => :'daemon.pidfile_path',
      -"SOCKDIR_PATH"                 => :'daemon.sockdir_path',
      -"BATCH_QUEUE_DEPTH"            => :'daemon.batch_queue_depth',
      -"BATCH_SAMPLE_SIZE"            => :'daemon.batch_sample_size',
      -"BATCH_FLUSH_INTERVAL"         => :'daemon.batch_flush_interval',
      -"DAEMON_TICK_INTERVAL"         => :'daemon.tick_interval',
      -"DAEMON_LOCK_CHECK_INTERVAL"   => :'daemon.lock_check_interval',
      -"DAEMON_INACTIVITY_TIMEOUT"    => :'daemon.inactivity_timeout',
      -"CLIENT_MAX_TRIES"             => :'daemon.max_connect_tries',
      -"CLIENT_CONN_TRY_WIN"          => :'daemon.connect_try_window',
      -"MAX_PRESPAWN_JITTER"          => :'daemon.max_prespawn_jitter',
      -"DAEMON_WAIT_TIMEOUT"          => :'daemon.wait_timeout',
      -"CLIENT_CHECK_INTERVAL"        => :'daemon.client_check_interval',
      -"CLIENT_QUEUE_DEPTH"           => :'daemon.client_queue_depth',
      -"CLIENT_WRITE_TIMEOUT"         => :'daemon.client_write_timeout',
      -"SSL_CERT_PATH"                => :'daemon.ssl_cert_path',
      -"SSL_CERT_DIR"                 => :'daemon.ssl_cert_dir',

      # == Legacy env vars ==
      #
      -"AGENT_LOCKFILE"               => :'agent.lockfile',
      -"AGENT_SOCKFILE_PATH"          => :'agent.sockfile_path',

      # == User config settings ==
      -"USER_CONFIG_PATH"             => :user_config_path,

      # == Heroku settings ==
      -"HEROKU_DYNO_INFO_PATH"        => :'heroku.dyno_info_path',

      # == Source Location ==
      -"SOURCE_LOCATION_IGNORED_GEMS" => :source_location_ignored_gems
    }.freeze

    KEY_TO_NATIVE_ENV = {
      # We use different log files for native and Ruby, but the native code doesn't know this
      native_log_file:  "LOG_FILE",
      native_log_level: "LOG_LEVEL"
    }.freeze

    SERVER_VALIDATE = %i[].freeze

    DEFAULT_IGNORED_SOURCE_LOCATION_GEMS = [
      -"skylight",
      -"activesupport",
      -"activerecord"
    ].freeze

    # Default values for Skylight configuration keys
    def self.default_values
      @default_values ||=
        begin
          ret = {
            # URLs
            auth_url:                  -"https://auth.skylight.io/agent",
            app_create_url:            -"https://www.skylight.io/apps",
            merges_url:                -"https://www.skylight.io/merges",
            validation_url:            -"https://auth.skylight.io/agent/config",

            # Logging
            log_file:                  -"-",
            log_level:                 -"INFO",
            alert_log_file:            -"-",
            log_sql_parse_errors:      true,

            # Features
            enable_segments:           true,
            enable_sidekiq:            false,
            sinatra_route_prefixes:    false,
            enable_source_locations:   true,

            # Deploys
            'heroku.dyno_info_path':   -"/etc/heroku/dyno",
            report_rails_env:          true,

            # Daemon
            'daemon.lazy_start':       true,
            hostname:                  Util::Hostname.default_hostname,
            report_max_spans_exceeded: false,
            prune_large_traces:        true
          }

          unless Util::Platform::OS == -"darwin"
            ret[:'daemon.ssl_cert_path'] = Util::SSL.ca_cert_file_or_default
            ret[:'daemon.ssl_cert_dir'] = Util::SSL.ca_cert_dir
          end

          if Skylight.native?
            native_path = Skylight.libskylight_path

            ret[:'daemon.lib_path'] = native_path
            ret[:'daemon.exec_path'] = File.join(native_path, "skylightd")
          end

          ret
        end
    end

    REQUIRED_KEYS = {
      authentication: "authentication token",
      hostname:       "server hostname",
      auth_url:       "authentication url",
      validation_url: "config validation url"
    }.freeze

    def self.native_env_keys
      @native_env_keys ||= %i[
        native_log_level
        native_log_file
        log_sql_parse_errors
        version
        root
        proxy_url
        hostname
        session_token
        auth_url
        auth_http_deflate
        auth_http_connect_timeout
        auth_http_read_timeout
        report_url
        report_http_deflate
        report_http_connect_timeout
        report_http_read_timeout
        report_http_disabled
        daemon.lazy_start
        daemon.exec_path
        daemon.lib_path
        daemon.pidfile_path
        daemon.sockdir_path
        daemon.batch_queue_depth
        daemon.batch_sample_size
        daemon.batch_flush_interval
        daemon.tick_interval
        daemon.lock_check_interval
        daemon.inactivity_timeout
        daemon.max_connect_tries
        daemon.connect_try_window
        daemon.max_prespawn_jitter
        daemon.wait_timeout
        daemon.client_check_interval
        daemon.client_queue_depth
        daemon.client_write_timeout
        daemon.ssl_cert_path
        daemon.ssl_cert_dir
      ]
    end

    # Maps legacy config keys to new config keys
    def self.legacy_keys
      @legacy_keys ||= {
        'agent.sockfile_path': :'daemon.sockdir_path',
        'agent.lockfile':      :'daemon.pidfile_path'
      }
    end

    def self.validators
      @validators ||= {
        'agent.interval': [->(v, _c) { v.is_a?(Integer) && v > 0 }, "must be an integer greater than 0"]
      }
    end

    # @api private
    attr_reader :priority_key

    # @api private
    def initialize(*args)
      attrs = {}

      if args.last.is_a?(Hash)
        attrs = args.pop.dup
      end

      @values = {}
      @priority = {}
      @priority_regexp = nil
      @alert_logger = nil
      @logger = nil

      p = attrs.delete(:priority)

      if (@priority_key = args[0])
        @priority_regexp = /^#{Regexp.escape(priority_key)}\.(.+)$/
      end

      attrs.each do |k, v|
        self[k] = v
      end

      p&.each do |k, v|
        @priority[self.class.remap_key(k)] = v
      end
    end

    def self.load(opts = {}, env = ENV)
      attrs = {}
      path = opts.delete(:file)
      priority_key = opts.delete(:priority_key)
      priority_key ||= opts[:env] # if a priority_key is not given, use env if available

      if path
        error = nil
        begin
          attrs = YAML.safe_load(ERB.new(File.read(path)).result,
                                 [], # permitted_classes
                                 [], # permitted_symbols
                                 true) # aliases enabled
          error = "empty file" unless attrs
          error = "invalid format" if attrs && !attrs.is_a?(Hash)
        rescue Exception => e
          error = e.message
        end

        raise ConfigError, "could not load config file; msg=#{error}" if error
      end

      # The key-value pairs in this `priority` option are inserted into the
      # config's @priority hash *after* anything listed under priority_key;
      # i.e., ENV takes precendence over priority_key
      if env
        attrs[:priority] = remap_env(env)
      end

      config = new(priority_key, attrs)

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
      if (proxy_url = Util::Proxy.detect_url(env))
        ret[:proxy_url] = proxy_url
      end

      env.each do |k, val|
        next unless k =~ /^(?:SK|SKYLIGHT)_(.+)$/
        next unless (key = ENV_TO_KEY[$1])

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

      ret
    end

    # @api private
    def validate!
      REQUIRED_KEYS.each do |k, v|
        unless get(k)
          raise ConfigError, "#{v} required"
        end
      end

      log_file = self[:log_file]
      alert_log_file = self[:alert_log_file]
      native_log_file = self.native_log_file

      check_logfile_permissions(log_file, "log_file")
      check_logfile_permissions(alert_log_file, "alert_log_file")
      # TODO: Support rotation interpolation in this check
      check_logfile_permissions(native_log_file, "native_log_file")

      # TODO: Move this out of the validate! method: https://github.com/tildeio/direwolf-agent/issues/273
      # FIXME: Why not set the sockdir_path and pidfile_path explicitly?
      # That way we don't have to keep this in sync with the Rust repo.
      sockdir_path = File.expand_path(self[:'daemon.sockdir_path'] || ".", root)
      pidfile_path = File.expand_path(self[:'daemon.pidfile_path'] || "skylight.pid", sockdir_path)

      check_file_permissions(pidfile_path, "daemon.pidfile_path or daemon.sockdir_path")
      check_sockdir_permissions(sockdir_path)

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
        raise ConfigError, "Directory `#{file_root}` is not writable. Please set #{key} in your config to a " \
                           "writable path"
      end
    end

    def check_logfile_permissions(log_file, key)
      return if log_file == "-" # STDOUT

      log_file = File.expand_path(log_file, root)
      check_file_permissions(log_file, key)
    end

    def key?(key)
      key = self.class.remap_key(key)
      @priority.key?(key) || @values.key?(key)
    end

    def get(key, default = nil)
      key = self.class.remap_key(key)

      return @priority[key] if @priority.key?(key)
      return @values[key]   if @values.key?(key)
      return self.class.default_values[key] if self.class.default_values.key?(key)

      if default
        return default
      elsif block_given?
        return yield key
      end

      nil
    end

    alias [] get

    def set(key, val, scope = nil)
      if scope
        key = [scope, key].join(".")
      end

      if val.is_a?(Hash)
        val.each do |k, v|
          set(k, v, key)
        end
      else
        k = self.class.remap_key(key)

        if (validator = self.class.validators[k])
          blk, msg = validator

          unless blk.call(val, self)
            error_msg = "invalid value for #{k} (#{val})"
            error_msg << ", #{msg}" if msg
            raise ConfigError, error_msg
          end
        end

        if @priority_regexp && k =~ @priority_regexp
          @priority[$1.to_sym] = val
        end

        @values[k] = val
      end
    end

    alias []= set

    def send_or_get(val)
      respond_to?(val) ? send(val) : get(val)
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

    def to_native_env
      ret = []

      self.class.native_env_keys.each do |key|
        value = send_or_get(key)
        unless value.nil?
          env_key = KEY_TO_NATIVE_ENV[key] || ENV_TO_KEY.key(key) || key.upcase
          ret << "SKYLIGHT_#{env_key}" << cast_for_env(value)
        end
      end

      ret << "SKYLIGHT_AUTHENTICATION" << authentication_with_meta
      ret << "SKYLIGHT_VALIDATE_AUTHENTICATION" << "false"

      ret
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
      @gc ||= GC.new(self, get("gc.profiler", VM::GC.new))
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

    # @api private
    def source_location_ignored_gems
      @source_location_ignored_gems ||=
        begin
          ignored_gems = get(:source_location_ignored_gems)
          if ignored_gems.is_a?(String)
            ignored_gems = ignored_gems.split(/\s*,\s*/)
          end

          Array(ignored_gems) | DEFAULT_IGNORED_SOURCE_LOCATION_GEMS
        end
    end

    def root
      @root ||= Pathname.new(self[:root] || Dir.pwd).realpath
    end

    def log_level
      @log_level ||=
        if trace?
          Logger::DEBUG
        else
          case get(:log_level)
          when /^debug$/i then Logger::DEBUG
          when /^info$/i  then Logger::INFO
          when /^warn$/i  then Logger::WARN
          when /^error$/i then Logger::ERROR
          when /^fatal$/i then Logger::FATAL
          else Logger::ERROR # rubocop:disable Lint/DuplicateBranch
          end
        end
    end

    def native_log_level
      @native_log_level ||=
        if trace?
          "trace"
        else
          case log_level
          when Logger::DEBUG then "debug"
          when Logger::INFO  then "info"
          when Logger::WARN  then "warn"
          else "error"
          end
        end
    end

    def logger
      @logger ||=
        MUTEX.synchronize do
          load_logger
        end
    end

    def native_log_file
      @native_log_file ||= get("native_log_file") do
        log_file = self["log_file"]
        return "-" if log_file == "-"

        parts = log_file.to_s.split(".")
        parts.insert(-2, "native")
        parts.join(".")
      end
    end

    attr_writer :logger, :alert_logger

    def alert_logger
      @alert_logger ||= MUTEX.synchronize do
        unless (l = @alert_logger)
          out = get(:alert_log_file)
          out = Util::AlertLogger.new(load_logger) if out == "-"

          l = create_logger(out, level: Logger::DEBUG)
        end

        l
      end
    end

    def enable_segments?
      !!get(:enable_segments)
    end

    def enable_sidekiq?
      !!get(:enable_sidekiq)
    end

    def sinatra_route_prefixes?
      !!get(:sinatra_route_prefixes)
    end

    def enable_source_locations?
      !!get(:enable_source_locations)
    end

    def user_config
      @user_config ||= UserConfig.new(self)
    end

    def on_heroku?
      File.exist?(get(:'heroku.dyno_info_path'))
    end

    private

      def create_logger(out, level: :info)
        if out.is_a?(String)
          out = File.expand_path(out, root)
          # May be redundant since we also do this in the permissions check
          FileUtils.mkdir_p(File.dirname(out))
        end

        Logger.new(out, progname: "Skylight", level: level)
      rescue
        Logger.new($stdout, progname: "Skylight", level: level)
      end

      def load_logger
        unless (l = @logger)
          out = get(:log_file)
          out = $stdout if out == "-"
          l = create_logger(out, level: log_level)
        end

        l
      end

      def cast_for_env(val)
        case val
        when true  then "true"
        when false then "false"
        when nil   then "nil"
        else val.to_s
        end
      end

    public

    # @api private
    def api
      @api ||= Api.new(self)
    end

    def validate_with_server
      res = api.validate_config

      unless res.token_valid?
        warn("Invalid authentication token")
        return false
      end

      if res.error_response?
        warn("Unable to reach server for config validation")
      end

      unless res.config_valid?
        warn("Invalid configuration") unless res.error_response?
        res.validation_errors.each do |k, v|
          warn("  #{k}: #{v}")
        end

        return false if res.forbidden?

        corrected_config = res.corrected_config

        # Use defaults if no corrected config is available. This will happen if the request failed.
        corrected_config ||= Hash[SERVER_VALIDATE.map { |k| [k, self.class.default_values.fetch(k)] }]

        config_to_update = corrected_config.reject { |k, v| get(k) == v }
        unless config_to_update.empty?
          info("Updating config values:")
          config_to_update.each do |k, v|
            info("  setting #{k} to #{v}")

            # This is a weird way to handle priorities
            # See https://github.com/tildeio/direwolf-agent/issues/275
            k = "#{priority_key}.#{k}" if priority_key

            set(k, v)
          end
        end
      end

      true
    end

    def check_sockdir_permissions(sockdir_path)
      # Try to make the directory, don't blow up if we can't. Our writable? check will fail later.
      FileUtils.mkdir_p sockdir_path rescue nil

      unless FileTest.writable?(sockdir_path)
        raise ConfigError, "Directory `#{sockdir_path}` is not writable. Please set daemon.sockdir_path in " \
                           "your config to a writable path"
      end

      if check_nfs(sockdir_path)
        raise ConfigError, "Directory `#{sockdir_path}` is an NFS mount and will not allow sockets. Please set " \
                           "daemon.sockdir_path in your config to a non-NFS path."
      end
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))

      File.open(path, "w") do |f|
        f.puts <<~YAML
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

    def authentication_with_meta
      token = get(:authentication)

      if token
        meta = {}
        meta.merge!(deploy.to_query_hash) if deploy
        meta[:reporting_env] = true if reporting_env?

        # A pipe should be a safe delimiter since it's not in the standard token
        # and is encoded by URI
        token += "|#{URI.encode_www_form(meta)}"
      end

      token
    end

    def deploy
      @deploy ||= Util::Deploy.build(self)
    end

    def components
      @components ||= {
        web:    Util::Component.new(
          get(:env),
          Util::Component::DEFAULT_NAME
        ),
        worker: Util::Component.new(
          get(:env),
          get(:component) || get(:worker_component),
          force_worker: true
        )
      }
    rescue ArgumentError => e
      raise ConfigError, e.message
    end

    def component
      components[:web]
    end

    def to_json(*)
      JSON.generate(as_json)
    end

    def as_json(*)
      {
        config: {
          priority: @priority.merge(component.as_json),
          values:   @values
        }
      }
    end

    private

      def check_nfs(path)
        # Should work on most *nix, though not on OS X
        `stat -f -L -c %T #{path} 2>&1`.strip == "nfs"
      end

      def reporting_env?
        # true if env was explicitly set,
        # or if we are auto-detecting via the opt-in SKYLIGHT_REPORT_RAILS_ENV=true
        !!(get(:report_rails_env) || get(:env))
      end
  end
end
