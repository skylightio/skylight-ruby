require 'skylight/version'

module Skylight
  # @api private
  TRACE_ENV_KEY = 'SKYLIGHT_ENABLE_TRACE_LOGS'.freeze

  # Load the native agent
  require 'skylight/native'

  # Specifically check for Railtie since we've had at least one case of a
  #   customer having Rails defined without having all of Rails loaded.
  if defined?(Rails::Railtie)
    require 'skylight/railtie'
  end

  require 'active_support/notifications'
  require 'skylight/compat' # Require after AS::N

  # Require VM specific things
  require 'skylight/config'
  require 'skylight/user_config'
  require 'skylight/gc'
  require 'skylight/helpers'
  require 'skylight/instrumenter'
  require 'skylight/middleware'
  require 'skylight/trace'
  require 'skylight/vm/gc'
  require 'skylight/util'

  # Used from the CLI
  autoload :Api,          'skylight/api'
  autoload :CLI,          'skylight/cli'
  autoload :Normalizers,  'skylight/normalizers'
  autoload :Subscriber,   'skylight/subscriber'

  # @api private
  class ConfigError < RuntimeError; end

  # @api private
  TIERS = %w(
    rack
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

  # Check tracing
  def self.tracing?
    inst = Instrumenter.instance
    inst && inst.current_trace
  end

  # Start a trace
  def self.trace(endpoint=nil, cat=nil, title=nil)
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    if block_given?
      inst.trace(endpoint, cat || DEFAULT_CATEGORY, title) { yield }
    else
      inst.trace(endpoint, cat || DEFAULT_CATEGORY, title)
    end
  end

  # End a trace
  def self.done(span)
    return unless inst = Instrumenter.instance
    inst.done(span)
  end

  # Instrument
  def self.instrument(opts = DEFAULT_OPTIONS, &block)
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    if Hash === opts
      category    = opts[:category] || DEFAULT_CATEGORY
      title       = opts[:title]
      desc        = opts[:description]
      if opts.key?(:annotations)
        warn "call to #instrument included deprecated annotations"
      end
    else
      category    = DEFAULT_CATEGORY
      title       = opts.to_s
      desc        = nil
    end

    inst.instrument(category, title, desc, &block)
  end

  # Temporarily disable
  def self.disable
    unless inst = Instrumenter.instance
      return yield if block_given?
      return
    end

    inst.disable { yield }
  end
end
