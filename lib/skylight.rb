require 'rbconfig'
require 'socket'
require 'skylight/version'

begin
  unless ENV["SKYLIGHT_DISABLE_AGENT"]
    require 'skylight_native'
    require 'skylight/native'
    has_native_ext = true
  end
rescue LoadError
  puts "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension wasn't found. Skylight is not running."
  raise if ENV.key?("SKYLIGHT_REQUIRED")
end

if has_native_ext

module Skylight
  TRACE_ENV_KEY      = 'SKYLIGHT_ENABLE_TRACE_LOGS'.freeze
  STANDALONE_ENV_KEY = 'SKYLIGHT_STANDALONE'.freeze
  STANDALONE_ENV_VAL = 'server'.freeze

  def self.daemon?
    ENV[STANDALONE_ENV_KEY] == STANDALONE_ENV_VAL
  end

  unless daemon?
    require 'active_support/notifications'
    require 'skylight/compat' # Require after AS::N

    # Require VM specific things
    require 'skylight/vm/gc'
  end

  autoload :Config,       'skylight/config'
  autoload :GC,           'skylight/gc'
  autoload :Helpers,      'skylight/helpers'
  autoload :Instrumenter, 'skylight/instrumenter'
  autoload :Messages,     'skylight/messages'
  autoload :Middleware,   'skylight/middleware'
  autoload :Normalizers,  'skylight/normalizers'
  autoload :Subscriber,   'skylight/subscriber'
  autoload :Worker,       'skylight/worker'

  module Util
    require 'skylight/util/clock'

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

  # ==== Exceptions ====
  class IpcProtoError    < RuntimeError; end
  class WorkerStateError < RuntimeError; end
  class ConfigError      < RuntimeError; end
  class TraceError       < RuntimeError; end
  class SerializeError   < RuntimeError; end

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
      category = opts.delete(:category)
      title    = opts.delete(:title)
      desc     = opts.delete(:description)
    else
      category = DEFAULT_CATEGORY
      title    = opts.to_s
      desc     = nil
    end

    if block_given?
      inst.instrument(category, title, desc) { yield }
    else
      inst.instrument(category, title, desc)
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

  if defined?(Rails)
    require 'skylight/railtie'
  end

  require 'skylight/probes'
end

else

module Skylight
  def self.start!(*)
  end

  def self.stop!(*)
  end

  def self.trace(*)
    yield if block_given?
  end

  def self.done(*)
  end

  def self.instrument(*)
    yield if block_given?
  end

  def self.disable(*)
    yield if block_given?
  end
end

end

module Skylight
  autoload :Api,          'skylight/api'
  autoload :CLI,          'skylight/cli'
end
