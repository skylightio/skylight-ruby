require "skylight/version"
require "skylight/trace"
require "skylight/instrumenter"
require "skylight/middleware"
require "skylight/api"
require "skylight/helpers"
require "skylight/config"
require "skylight/user_config"
require "skylight/errors"
require "skylight/native"
require "skylight/gc"
require "skylight/vm/gc"
require "skylight/util"
require "skylight/deprecation"
require "skylight/subscriber"
require "skylight/sidekiq"
require "skylight/probes"

# For prettier global names
require "English"

module Skylight
  # Used from the CLI
  autoload :CLI, "skylight/cli"
  # Is this autoload even useful?
  autoload :Normalizers, "skylight/normalizers"

  # Specifically check for Railtie since we've had at least one case of a
  #   customer having Rails defined without having all of Rails loaded.
  if defined?(Rails::Railtie)
    require "skylight/railtie"
  end

  extend Util::Logging

  LOCK = Mutex.new

  at_exit { stop! }

  class << self
    def instrumenter
      defined?(@instrumenter) && @instrumenter
    end

    def probe(*args)
      Probes.probe(*args)
    end

    def enable_normalizer(*names)
      Normalizers.enable(*names)
    end

    # Start instrumenting
    def start!(config = nil)
      return instrumenter if instrumenter

      const_get(:LOCK).synchronize do
        return instrumenter if instrumenter

        config ||= {}
        config = Config.load(config) unless config.is_a?(Config)

        @instrumenter = Instrumenter.new(config).start!
      end
    rescue => e
      level, message =
        if e.is_a?(ConfigError)
          [:warn, format("Unable to start Instrumenter due to a configuration error: %<message>s",
                          message: e.message)]
        else
          [:error, format("Unable to start Instrumenter; msg=%<message>s; class=%<klass>s",
                          message: e.message, klass: e.class)]
        end

      if config && config.respond_to?("log_#{level}") && config.respond_to?(:log_trace)
        config.send("log_#{level}", message)
        config.log_trace e.backtrace.join("\n")
      else
        warn "[#{name.upcase}] #{message}"
      end
      false
    end

    def started?
      !!instrumenter
    end

    # Stop instrumenting
    def stop!
      t { "stop!" }

      const_get(:LOCK).synchronize do
        t { "stop! synchronized" }
        return unless instrumenter
        # This is only really helpful for getting specs to pass.
        @instrumenter.current_trace = nil

        @instrumenter.shutdown
        @instrumenter = nil
      end
    end

    # Check tracing
    def tracing?
      t { "checking tracing?; thread=#{Thread.current.object_id}" }
      instrumenter && instrumenter.current_trace
    end

    # Start a trace
    def trace(endpoint = nil, cat = nil, title = nil, meta: nil, segment: nil, component: nil)
      unless instrumenter
        return yield if block_given?
        return
      end

      if instrumenter.poisoned?
        spawn_shutdown_thread!
        return yield if block_given?
        return
      end

      cat ||= DEFAULT_CATEGORY

      if block_given?
        instrumenter.trace(endpoint, cat, title, nil, meta: meta, segment: segment, component: component) { |tr| yield tr }
      else
        instrumenter.trace(endpoint, cat, title, nil, meta: meta, segment: segment, component: component)
      end
    end

    # Instrument
    def instrument(opts = DEFAULT_OPTIONS, &block)
      unless instrumenter
        return yield if block_given?
        return
      end

      if opts.is_a?(Hash)
        category    = opts[:category] || DEFAULT_CATEGORY
        title       = opts[:title]
        desc        = opts[:description]
        meta        = opts[:meta]
        if opts.key?(:annotations)
          warn "call to #instrument included deprecated annotations"
        end
      else
        category    = DEFAULT_CATEGORY
        title       = opts.to_s
        desc        = nil
        meta        = nil
      end

      instrumenter.instrument(category, title, desc, meta, &block)
    end

    def mute
      unless instrumenter
        return yield if block_given?
        return
      end

      instrumenter.mute do
        yield if block_given?
      end
    end

    def unmute
      unless instrumenter
        return yield if block_given?
        return
      end

      instrumenter.unmute do
        yield if block_given?
      end
    end

    def muted?
      instrumenter&.muted?
    end

    # End a span
    def done(span, meta = nil)
      return unless instrumenter
      instrumenter.done(span, meta)
    end

    def broken!
      return unless instrumenter
      instrumenter.broken!
    end

    # Temporarily disable
    def disable
      unless instrumenter
        return yield if block_given?
        return
      end

      instrumenter.disable { yield }
    end

    def config
      return unless instrumenter
      instrumenter.config
    end

    # Runs the shutdown procedure in the background.
    # This should do little more than unsubscribe from all ActiveSupport::Notifications
    def spawn_shutdown_thread!
      @shutdown_thread || const_get(:LOCK).synchronize do
        @shutdown_thread ||= Thread.new { @instrumenter&.shutdown }
      end
    end
  end

  # Some methods exepected to be defined by the native code (OUTDATED)
  #
  #   * Skylight::Util::Clock#native_hrtime
  #       - returns current time in nanoseconds
  #   * Skylight::Trace#native_new(start, uuid, endpoint)
  #       - start is milliseconds
  #       - uuid is currently unused
  #       - endpoint is the endpoint name
  #       - returns an instance of Trace
  #   * Skylight::Trace#native_get_started_at
  #       - returns the start time
  #   * Skylight::Trace#native_get_endpoint
  #       - returns the endpoint name
  #   * Skylight::Trace#native_set_endpoint(endpoint)
  #       - returns nil
  #   * Skylight::Trace#native_get_uuid
  #       - returns the uuid
  #   * Skylight::Trace#native_start_span(time, category)
  #       - time is milliseconds
  #       - category is a string
  #       - returns a numeric span id
  #   * Skylight::Trace#native_stop_span(span, time)
  #       - span is the span id
  #       - time is milliseconds
  #       - returns nil
  #   * Skylight::Trace#native_span_set_title(span, title)
  #       - span is the span id
  #       - title is a string
  #       - returns nil
  #   * Skylight::Trace#native_span_set_description(span, desc)
  #       - span is the span id
  #       - desc is a string
  #       - returns nil
  #   * Skylight::Instrumenter#native_new(env)
  #       - env is the config converted to a flattened array of ENV style values
  #             e.g. `["SKYLIGHT_AUTHENTICATION", "abc123", ...]
  #       - returns a new Instrumenter instance
  #   * Skylight::Instrumenter#native_start()
  #       - returns a truthy value if successful
  #   * Skylight::Instrumenter#native_stop()
  #       - returns nil
  #   * Skylight::Instrumenter#native_submit_trace(trace)
  #       - trace is a Trace instance
  #       - returns nil
  #   * Skylight::Instrumenter#native_track_desc(endpoint, description)
  #       - endpoint is a string
  #       - description is a string
  #       - returns truthy unless uniqueness cap exceeded

  require "active_support/notifications"

  # @api private
  TIERS = %w[
    rack
    api
    app
    view
    db
    noise
    other
  ].freeze

  # @api private
  TIER_REGEX = /^(?:#{TIERS.join('|')})(?:\.|$)/u

  # @api private
  CATEGORY_REGEX = /^[a-z0-9_-]+(?:\.[a-z0-9_-]+)*$/iu

  # @api private
  DEFAULT_CATEGORY = "app.block".freeze

  # @api private
  DEFAULT_OPTIONS = { category: DEFAULT_CATEGORY }.freeze
end
