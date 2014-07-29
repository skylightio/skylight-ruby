require 'rbconfig'
require 'socket'
require 'skylight/version'

module Skylight
  # @api private
  TRACE_ENV_KEY      = 'SKYLIGHT_ENABLE_TRACE_LOGS'.freeze

  # @api private
  STANDALONE_ENV_KEY = 'SKYLIGHT_STANDALONE'.freeze

  # @api private
  STANDALONE_ENV_VAL = 'server'.freeze

  # @api private
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

  if defined?(Rails)
    require 'skylight/railtie'
  end

  # @api private
  def self.check_install_errors(config)
    # Note: An unsupported arch doesn't count as an error.
    install_log = File.expand_path("../../ext/install.log", __FILE__)

    if File.exist?(install_log) && File.read(install_log) =~ /ERROR/
      config.alert_logger.error \
          "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension failed to install. " \
          "Please check #{install_log} and notify support@skylight.io." \
          "The missing extension will not affect the functioning of your application."
    end
  end

  # @api private
  def self.warn_skylight_native_missing(config)
    # TODO: Dumping the error messages this way is pretty hacky
    is_rails = defined?(Rails)
    env_name = is_rails ? Rails.env : "development"

    if env_name == "development" || env_name == "test"
      config.alert_logger.warn \
          "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in #{env_name} mode. " \
          "No data will be reported until you deploy your app.\n" \
          "(To disable this message, set `alert_logger_file` in your config.)"
    else
      config.alert_logger.error \
          "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for your platform wasn't found. " \
          "The monitoring portion of Skylight is only supported on production servers running 32- or " \
          "64-bit Linux. The missing extension will not affect the functioning of your application " \
          "and you can continue local development without data being reported. If you are on a " \
          "supported platform, please contact support at support@skylight.io."
    end
  end

  # @api private
  def self.daemon?
    ENV[STANDALONE_ENV_KEY] == STANDALONE_ENV_VAL
  end

  unless daemon?
    require 'active_support/notifications'
    require 'skylight/compat' # Require after AS::N

    # Require VM specific things
    require 'skylight/vm/gc'
  end

  autoload :Api,          'skylight/api'
  autoload :CLI,          'skylight/cli'
  autoload :Config,       'skylight/config'
  autoload :Helpers,      'skylight/helpers'
  autoload :Formatters,   'skylight/formatters'
  autoload :GC,           'skylight/gc'
  autoload :Instrumenter, 'skylight/instrumenter'
  autoload :Messages,     'skylight/messages'
  autoload :Metrics,      'skylight/metrics'
  autoload :Middleware,   'skylight/middleware'
  autoload :Normalizers,  'skylight/normalizers'
  autoload :Subscriber,   'skylight/subscriber'
  autoload :Worker,       'skylight/worker'

  # Skylight::Util is defined by the native ext so we can't autoload
  require 'skylight/util'

  # ==== Exceptions ====

  # @api private
  class IpcProtoError    < RuntimeError; end

  # @api private
  class WorkerStateError < RuntimeError; end

  # @api private
  class ConfigError      < RuntimeError; end

  # @api private
  class TraceError       < RuntimeError; end

  # @api private
  class SerializeError   < RuntimeError; end

  # @api private
  TIERS = %w(
    api
    app
    view
    db
    noise
    other)

  # @api private
  TIER_REGEX = /^(?:#{TIERS.join('|')})(?:\.|$)/u

  # @api private
  CATEGORY_REGEX = /^[a-z0-9_-]+(?:\.[a-z0-9_-]+)*$/iu

  # @api private
  DEFAULT_CATEGORY = "app.block".freeze

  # @api private
  DEFAULT_OPTIONS = { category: DEFAULT_CATEGORY }

  # Start instrumenting
  def self.start!(*args)
    Instrumenter.start!(*args)
  end

  # Stop instrumenting
  def self.stop!(*args)
    Instrumenter.stop!(*args)
  end

  # Start a trace
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

  # End a trace
  def self.done(span)
    return unless inst = Instrumenter.instance
    inst.done(span)
  end

  # Instrument
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

  # Temporarily disable
  def self.disable
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    inst.disable { yield }
  end

  # @api private
  RUBYBIN = File.join(
    RbConfig::CONFIG['bindir'],
    "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}")

  # Called by the standalone agent
  Worker::Server.boot if daemon?

  require 'skylight/probes'
end
