require 'yaml'
require 'fileutils'
require 'logger'
require 'thread'
require 'socket'

module Skylight
  class Config
    MUTEX = Mutex.new

    def self.default_hostname
      if hostname = Socket.gethostname
        hostname.strip!
        hostname = nil if hostname == ''
      end

      hostname || "gen-#{SecureRandom.uuid}"
    end

    # Map environment variable keys with Skylight configuration keys
    ENV_TO_KEY = {
      'ROOT'                => :'root',
      'LOG_FILE'            => :'log_file',
      'LOG_LEVEL'           => :'log_level',
      'APPLICATION'         => :'application',
      'AUTHENTICATION'      => :'authentication',
      'HOSTNAME'            => :'hostname',
      'AGENT_INTERVAL'      => :'agent.interval',
      'AGENT_KEEPALIVE'     => :'agent.keepalive',
      'AGENT_SAMPLE_SIZE'   => :'agent.sample',
      'AGENT_SOCKFILE_PATH' => :'agent.sockfile_path',
      'AGENT_STRATEGY'      => :'agent.strategy',
      'AGENT_MAX_MEMORY'    => :'agent.max_memory',
      'REPORT_HOST'         => :'report.host',
      'REPORT_PORT'         => :'report.port',
      'REPORT_SSL'          => :'report.ssl',
      'REPORT_DEFLATE'      => :'report.deflate',
      'ACCOUNTS_HOST'       => :'accounts.host',
      'ACCOUNTS_PORT'       => :'accounts.port',
      'ACCOUNTS_SSL'        => :'accounts.ssl',
      'ACCOUNTS_DEFLATE'    => :'accounts.deflate',
      'ME_AUTHENTICATION'   => :'me.authentication',
      'ME_CREDENTIALS_PATH' => :'me.credentials_path',
      'TEST_CONSTANT_FLUSH' => :'test.constant_flush',
      'TEST_IGNORE_TOKEN'   => :'test.ignore_token' }

    # Default values for Skylight configuration keys
    DEFAULTS = {
      :'log_file'            => '-'.freeze,
      :'log_level'           => 'INFO'.freeze,
      :'hostname'            => default_hostname,
      :'agent.keepalive'     => 60,
      :'agent.interval'      => 5,
      :'agent.sample'        => 200,
      :'agent.max_memory'    => 256, # MB
      :'report.host'         => 'agent.skylight.io'.freeze,
      :'report.port'         => 443,
      :'report.ssl'          => true,
      :'report.deflate'      => true,
      :'accounts.host'       => 'www.skylight.io'.freeze,
      :'accounts.port'       => 443,
      :'accounts.ssl'        => true,
      :'accounts.deflate'    => false,
      :'me.credentials_path' => '~/.skylight' }.freeze

    REQUIRED = {
      :'authentication' => "authentication token",
      :'hostname'       => "server hostname",
      :'report.host'    => "skylight remote host",
      :'report.port'    => "skylight remote port" }

    VALIDATORS = {
      :'agent.interval' => lambda { |v, c| Integer === v && v > 0 }
    }

    def self.load(path = nil, environment = nil, env = ENV)
      attrs   = {}
      version = nil

      if path
        begin
          attrs = YAML.load_file(path)
        rescue Exception => e
          raise ConfigError, "could not load config file; msg=#{e.message}"
        end

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

    def self.remap_env(env)
      ret = {}

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
      end if env

      ret
    end

    attr_reader :environment

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
          @priority[k.to_sym] = v
        end
      end
    end

    def validate!
      REQUIRED.each do |k, v|
        unless get(k)
          raise ConfigError, "#{v} required"
        end
      end

      true
    end

    def key?(key)
      key = key.to_sym
      @priority.key?(key) || @values.key?(key)
    end

    def get(key, default = nil, &blk)
      key = key.to_sym

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
        k = key.to_sym

        if validator = VALIDATORS[k]
          unless validator.call(val, self)
            raise ConfigError, "invalid value for #{k} (#{val})"
          end
        end

        if @regexp && key =~ @regexp
          @priority[$1.to_sym] = val
        end

        @values[k] = val
      end
    end

    alias []= set

    def to_env
      ret = {}

      ENV_TO_KEY.each do |k, v|
        if (c = get(v)) != DEFAULTS[v]
          ret["SKYLIGHT_#{k}"] = cast_for_env(c)
        end
      end

      ret
    end

    #
    #
    # ===== Writing =====
    #
    #

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

    def worker
      Worker::Builder.new(self)
    end

    def gc
      @gc ||= GC.new(self, get('gc.profiler', VM::GC.new))
    end

    def constant_flush?
      get('test.constant_flush')
    end

    def ignore_token?
      get('test.ignore_token')
    end

    def root
      self[:root] || Dir.pwd
    end

    def logger
      @logger ||=
        begin
          MUTEX.synchronize do
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
        end
    end

    def logger=(logger)
      @logger = logger
    end

  private

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
