require 'rbconfig'
require 'socket'
require 'skylight/version'

module Skylight
  TRACE_ENV_KEY      = 'SKYLIGHT_ENABLE_TRACE_LOGS'.freeze
  STANDALONE_ENV_KEY = 'SKYLIGHT_STANDALONE'.freeze
  STANDALONE_ENV_VAL = 'server'.freeze

  # Whether or not the native extension is present
  @@has_native_ext = false

  def self.native?
    @@has_native_ext
  end

  begin
    unless ENV["SKYLIGHT_DISABLE_AGENT"]
      # First attempt to require the native extension
      require 'skylight_native'

      # If nothing was thrown, then the native extension is present
      @@has_native_ext = true

      # Require ruby support for the native extension
      require 'skylight/native'
    end
  rescue LoadError
    raise if ENV.key?("SKYLIGHT_REQUIRED")
  end

  autoload :Api,          'skylight/api'
  autoload :CLI,          'skylight/cli'
  autoload :Config,       'skylight/config'
  autoload :Helpers,      'skylight/helpers'

  module Util
    autoload :Logging,       'skylight/util/logging'
    autoload :HTTP,          'skylight/util/http'
  end

  # ==== Exceptions ====
  class IpcProtoError    < RuntimeError; end
  class WorkerStateError < RuntimeError; end
  class ConfigError      < RuntimeError; end
  class TraceError       < RuntimeError; end
  class SerializeError   < RuntimeError; end

  if defined?(Rails)
    require 'skylight/railtie'
  end

  def self.warn_skylight_native_missing
    # TODO: Dumping the error messages this way is pretty hacky
    if defined?(Rails) && !Rails.env.development? && !Rails.env.test?
      puts "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your platform wasn't found. We currently support monitoring in 32- and 64-bit Linux only. If you are on a supported platform, please contact support at support@skylight.io. The missing extension will not affect the functioning of your application."
    elsif defined?(Rails)
      puts "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in #{Rails.env} mode. No data will be reported until you deploy your app."
    else
      puts "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode."
    end
  end

  def self.daemon?
    ENV[STANDALONE_ENV_KEY] == STANDALONE_ENV_VAL
  end

  unless daemon?
    require 'active_support/notifications'
    require 'skylight/compat' # Require after AS::N

    # Require VM specific things
    require 'skylight/vm/gc'
  end

  autoload :GC,           'skylight/gc'
  autoload :Instrumenter, 'skylight/instrumenter'
  autoload :Messages,     'skylight/messages'
  autoload :Middleware,   'skylight/middleware'
  autoload :Normalizers,  'skylight/normalizers'
  autoload :Subscriber,   'skylight/subscriber'
  autoload :Worker,       'skylight/worker'

  module Metrics
    autoload :Meter,           'skylight/metrics/meter'
    autoload :EWMA,            'skylight/metrics/ewma'
    autoload :ProcessMemGauge, 'skylight/metrics/process_mem_gauge'
    autoload :ProcessCpuGauge, 'skylight/metrics/process_cpu_gauge'
  end

  module Util
    require 'skylight/util/clock'

    autoload :Conversions,   'skylight/util/conversions'
    autoload :Gzip,          'skylight/util/gzip'
    autoload :HTTP,          'skylight/util/http'
    autoload :Inflector,     'skylight/util/inflector'
    autoload :Logging,       'skylight/util/logging'
    autoload :Queue,         'skylight/util/queue'
    autoload :Task,          'skylight/util/task'
    autoload :UniformSample, 'skylight/util/uniform_sample'
  end

  module Formatters
    autoload :HTTP, 'skylight/formatters/http'
  end

  TIERS = %w(
    api
    app
    view
    db
    noise
    other)

  TIER_REGEX = /^(?:#{TIERS.join('|')})(?:\.|$)/u
  CATEGORY_REGEX = /^[a-z0-9_-]+(?:\.[a-z0-9_-]+)*$/iu
  DEFAULT_CATEGORY = "app.block".freeze
  DEFAULT_OPTIONS = { category: DEFAULT_CATEGORY }

  #
  #
  # ===== Public API =====
  #
  #

  def self.start!(*args)
    Instrumenter.start!(*args)
  end

  def self.stop!(*args)
    Instrumenter.stop!(*args)
  end

  def self.trace(endpoint=nil, cat=nil, title=nil)
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    if block_given?
      inst.trace(endpoint, cat, title) { yield }
    else
      inst.trace(endpoint, cat, title)
    end
  end

  def self.done(span)
    return unless inst = Instrumenter.instance
    inst.done(span)
  end

  def self.instrument(opts = DEFAULT_OPTIONS)
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    if Hash === opts
      category    = opts[:category] || DEFAULT_CATEGORY
      title       = opts[:title]
      desc        = opts[:description]
      annotations = opts[:annotations]
    else
      category    = DEFAULT_CATEGORY
      title       = opts.to_s
      desc        = nil
      annotations = nil
    end

    if block_given?
      inst.instrument(category, title, desc, annotations) { yield }
    else
      inst.instrument(category, title, desc, annotations)
    end
  end

  def self.disable
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    inst.disable { yield }
  end

  RUBYBIN = File.join(
    RbConfig::CONFIG['bindir'],
    "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}")

  # Called by the standalone agent
  Worker::Server.boot if daemon?

  require 'skylight/probes'
end
