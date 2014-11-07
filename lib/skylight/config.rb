require 'uri'
require 'yaml'
require 'fileutils'
require 'thread'
require 'openssl'
require 'skylight/util/hostname'
require 'skylight/util/logging'
require 'skylight/util/platform'
require 'skylight/util/ssl'

module Skylight
  class Config
    # @api private
    MUTEX = Mutex.new

    # Map environment variable keys with Skylight configuration keys
    ENV_TO_KEY = {
      # == Authentication ==
      'AUTHENTICATION' => :'authentication',

      # == Version ==
      'VERSION' => :'version',

      # == App settings ==
      'ROOT'          => :'root',
      'APPLICATION'   => :'application',
      'HOSTNAME'      => :'hostname',
      'SESSION_TOKEN' => :'session_token',

      # == Logging ==
      'LOG_FILE'       => :'log_file',
      'LOG_LEVEL'      => :'log_level',
      'ALERT_LOG_FILE' => :'alert_log_file',

      # == Proxy ==
      'PROXY_URL' => :'proxy_url',

      # == Instrumenter ==
      "IGNORED_ENDPOINT" => :'ignored_endpoint',

      # == Skylight Remote ==
      "AUTH_URL"                     => :'auth_url',
      "AUTH_HTTP_DEFLATE"            => :'auth_http_deflate',
      "AUTH_HTTP_CONNECT_TIMEOUT"    => :'auth_http_connect_timeout',
      "AUTH_HTTP_READ_TIMEOUT"       => :'auth_http_read_timeout',
      "REPORT_URL"                   => :'report_url',
      "REPORT_HTTP_DEFLATE"          => :'report_http_deflate',
      "REPORT_HTTP_CONNECT_TIMEOUT"  => :'report_http_connect_timeout',
      "REPORT_HTTP_READ_TIMEOUT"     => :'report_http_read_timeout',

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

      # == Legacy env vars ==
      #
      'AGENT_LOCKFILE'      => :'agent.lockfile',
      'AGENT_SOCKFILE_PATH' => :'agent.sockfile_path',
    }

    # Default values for Skylight configuration keys
    DEFAULTS = {
      :'version'              => VERSION,
      :'auth_url'             => 'https://auth.skylight.io/agent',
      :'daemon.lazy_start'    => true,
      :'daemon.ssl_cert_path' => Util::SSL.ca_cert_file_or_default,
      :'daemon.ssl_cert_dir'  => Util::SSL.ca_cert_dir,

      # == Legacy ==
      :'log_file'                => '-'.freeze,
      :'log_level'               => 'INFO'.freeze,
      :'alert_log_file'          => '-'.freeze,
      :'hostname'                => Util::Hostname.default_hostname,
      :'agent.keepalive'         => 60,
      :'agent.interval'          => 5,
      :'agent.sample'            => 200,
      :'agent.max_memory'        => 256, # MB
      :'report.host'             => 'agent.skylight.io'.freeze,
      :'report.port'             => 443,
      :'report.ssl'              => true,
      :'report.deflate'          => true,
      :'accounts.host'           => 'www.skylight.io'.freeze,
      :'accounts.port'           => 443,
      :'accounts.ssl'            => true,
      :'accounts.deflate'        => false,
      :'me.credentials_path'     => '~/.skylight',
      :'metrics.report_interval' => 60
    }

    if Skylight.native?
      native_path = Skylight.libskylight_path

      DEFAULTS[:'daemon.lib_path'] = native_path
      DEFAULTS[:'daemon.exec_path'] = File.join(native_path, 'skylightd')
    end

    DEFAULTS.freeze

    REQUIRED = {
      :'authentication' => "authentication token",
      :'hostname'       => "server hostname",
      :'report.host'    => "skylight remote host",
      :'report.port'    => "skylight remote port" }

    ALWAYS_INCLUDE_IN_ENV = [
      :version,
      :'daemon.lazy_start',
      :'daemon.lib_path',
      :'daemon.exec_path',
      :'daemon.ssl_cert_dir',
      :'daemon.ssl_cert_path' ]

    # Maps legacy config keys to new config keys
    LEGACY = {
      :'agent.sockfile_path' => :'daemon.sockdir_path',
      :'agent.pidfile_path'  => :'agent.lockfile',
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

    def self.load(path = nil, environment = nil, env = ENV)
      attrs   = {}
      version = nil

      if path
        error = nil
        begin
          attrs = YAML.load_file(path)
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

      new(environment, attrs)
    end

    def self.load_from_env(env = ENV)
      self.load(nil, nil, env)
    end

    def self.remap_key(key)
      key = key.to_sym
      LEGACY[key] || key
    end

    # @api private
    def self.remap_env(env)
      ret = {}

      return ret unless env

      ret[:proxy_url] = detect_proxy_url(env)

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

    def self.detect_proxy_url(env)
      if u = env['HTTP_PROXY'] || env['http_proxy']
        u = "http://#{u}" unless u =~ %r[://]
        u
      end
    end

    # @api private
    def skip_validation?
      !!get(:skip_validation)
    end

    # @api private
    def validate!
      return true if skip_validation?

      REQUIRED.each do |k, v|
        unless get(k)
          raise ConfigError, "#{v} required"
        end
      end

      sockdir_path = self[:'daemon.sockdir_path'] || File.expand_path('.')
      pidfile_path = self[:'daemon.pidfile_path'] || File.expand_path('skylight.pid', sockdir_path)

      check_permissions(pidfile_path, sockdir_path)

      true
    end

    def check_permissions(pidfile, sockdir_path)
      pidfile_root = File.dirname(pidfile)

      FileUtils.mkdir_p pidfile_root
      FileUtils.mkdir_p sockdir_path

      if File.exist?(pidfile)
        if !FileTest.writable?(pidfile)
          raise "`#{pidfile}` not writable. Please set daemon.pidfile_path or daemon.sockdir_path in your config to a writable path."
        end
      else
        if !FileTest.writable?(pidfile_root)
          raise "`#{pidfile_root}` not writable. Please set daemon.pidfile_path or daemon.sockdir_path in your config to a writable path."
        end
      end

      unless FileTest.writable?(sockdir_path)
        raise "`#{sockdir_path}` not writable. Please set daemon.sockdir_path in your config to a writable path."
      end
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

    def to_env
      ret = []

      ENV_TO_KEY.each do |k, v|
        next if LEGACY[v]
        c = get(v)
        # Always need to pass daemon lib_path config even when default
        if c != DEFAULTS[v] || ALWAYS_INCLUDE_IN_ENV.include?(v)
          ret << "SKYLIGHT_#{k}" << cast_for_env(c) if c
        end
      end

      ret << "SKYLIGHT_VALIDATE_AUTHENTICATION"
      ret << "false"

      ret
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))

      File.open(path, 'w') do |f|
        f.puts <<-YAML
---
# The Skylight ID for the application.
application: #{self[:application]}

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

    # @api private
    def gc
      @gc ||= GC.new(self, get('gc.profiler', VM::GC.new))
    end

    # @api private
    def ignore_token?
      get('test.ignore_token')
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
      @alert_logger ||=
        begin
          MUTEX.synchronize do
            unless l = @alert_logger
              out = get(:'alert_log_file')

              if out == '-'
                out = Util::AlertLogger.new(load_logger)
              elsif !(IO === out)
                out = File.expand_path(out, root)
                FileUtils.mkdir_p(File.dirname(out))
              end

              l = Logger.new(out)
              l.level = Logger::DEBUG
            end

            l
          end
        end
    end

    def alert_logger=(logger)
      @alert_logger = logger
    end

  private

    def load_logger
      unless l = @logger
        out = get(:'log_file')
        out = STDOUT if out == '-'

        unless IO === out
          out = File.expand_path(out, root)
          FileUtils.mkdir_p(File.dirname(out))
        end

        l = Logger.new(out)
        l.level =
          case get(:'log_level')
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
