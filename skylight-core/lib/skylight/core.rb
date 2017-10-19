require 'skylight/core/version'

module Skylight
  module Core
    # @api private
    class ConfigError < RuntimeError; end

    autoload :Normalizers,  'skylight/core/normalizers'
  end

  # @api private
  TRACE_ENV_KEY = 'SKYLIGHT_ENABLE_TRACE_LOGS'.freeze

  # Specifically check for Railtie since we've had at least one case of a
  #   customer having Rails defined without having all of Rails loaded.
  if defined?(Rails::Railtie)
    require 'skylight/core/railtie'
  end

  # When Skylight.native? is true, we should have the following:
  #   * Skylight::Core::Util::Clock#native_hrtime
  #       - returns current time in nanoseconds
  #   * Skylight::Core::Trace#native_new(start, uuid, endpoint)
  #       - start is milliseconds
  #       - uuid is currently unused
  #       - endpoint is the endpoint name
  #       - returns an instance of Trace
  #   * Skylight::Core::Trace#native_get_started_at
  #       - returns the start time
  #   * Skylight::Core::Trace#native_get_endpoint
  #       - returns the endpoint name
  #   * Skylight::Core::Trace#native_set_endpoint(endpoint)
  #       - returns nil
  #   * Skylight::Core::Trace#native_get_uuid
  #       - returns the uuid
  #   * Skylight::Core::Trace#native_start_span(time, category)
  #       - time is milliseconds
  #       - category is a string
  #       - returns a numeric span id
  #   * Skylight::Core::Trace#native_stop_span(span, time)
  #       - span is the span id
  #       - time is milliseconds
  #       - returns nil
  #   * Skylight::Core::Trace#native_span_set_title(span, title)
  #       - span is the span id
  #       - title is a string
  #       - returns nil
  #   * Skylight::Core::Trace#native_span_set_description(span, desc)
  #       - span is the span id
  #       - desc is a string
  #       - returns nil
  #   * Skylight::Core::Instrumenter#native_new(env)
  #       - env is the config converted to a flattened array of ENV style values
  #             e.g. `["SKYLIGHT_AUTHENTICATION", "abc123", ...]
  #       - returns a new Instrumenter instance
  #   * Skylight::Core::Instrumenter#native_start()
  #       - returns a truthy value if successful
  #   * Skylight::Core::Instrumenter#native_stop()
  #       - returns nil
  #   * Skylight::Core::Instrumenter#native_submit_trace(trace)
  #       - trace is a Trace instance
  #       - returns nil
  #   * Skylight::Core::Instrumenter#native_track_desc(endpoint, description)
  #       - endpoint is a string
  #       - description is a string
  #       - returns truthy unless uniqueness cap exceeded

  # FIXME: This is a hack
  class << self
    unless method_defined?(:native?)
      def native?
        false
      end
    end
  end

  require 'active_support/notifications'

  require 'skylight/core/config'
  require 'skylight/core/user_config'
  require 'skylight/core/gc'
  require 'skylight/core/helpers'
  require 'skylight/core/instrumenter'
  require 'skylight/core/trace'
  require 'skylight/core/vm/gc'
  require 'skylight/core/util'
  require 'skylight/core/middleware'
  require 'skylight/core/subscriber'

  require 'skylight/core/probes'

  # Shorthand
  Helpers = Core::Helpers
  Middleware = Core::Middleware

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

  # Install probes
  def self.probe(*probes)
    Skylight::Core::Probes.probe(*probes)
  end

  # Start instrumenting
  def self.start!(*args)
    Core::Instrumenter.start!(*args)
  end

  # Stop instrumenting
  def self.stop!(*args)
    Core::Instrumenter.stop!(*args)
  end

  # Check tracing
  def self.tracing?
    inst = Core::Instrumenter.instance
    inst && inst.current_trace
  end

  # Start a trace
  def self.trace(endpoint=nil, cat=nil, title=nil)
    unless inst = Core::Instrumenter.instance
      return yield if block_given?
      return
    end

    if block_given?
      inst.trace(endpoint, cat || DEFAULT_CATEGORY, title) { yield }
    else
      inst.trace(endpoint, cat || DEFAULT_CATEGORY, title)
    end
  end

  # Instrument
  def self.instrument(opts = DEFAULT_OPTIONS, &block)
    unless inst = Core::Instrumenter.instance
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

  # End a span
  def self.done(span)
    return unless inst = Core::Instrumenter.instance
    inst.done(span)
  end

  # Temporarily disable
  def self.disable
    unless inst = Core::Instrumenter.instance
      return yield if block_given?
      return
    end

    inst.disable { yield }
  end
end
