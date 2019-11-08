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

require "active_support/notifications"

# Specifically check for Railtie since we've had at least one case of a
#   customer having Rails defined without having all of Rails loaded.
if defined?(Rails::Railtie)
  require "skylight/railtie"
end

module Skylight
  # Used from the CLI
  autoload :CLI, "skylight/cli"
  # Is this autoload even useful?
  autoload :Normalizers, "skylight/normalizers"

  extend Util::Logging

  LOCK = Mutex.new

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

  at_exit { stop! }

  class << self
    extend Util::InstrumenterMethod

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
      instrumenter&.current_trace
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
        instrumenter.trace(endpoint, cat, title, nil, meta: meta, segment: segment, component: component) do |tr|
          yield tr
        end
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
      else
        category    = DEFAULT_CATEGORY
        title       = opts.to_s
        desc        = nil
        meta        = nil
      end

      instrumenter.instrument(category, title, desc, meta, &block)
    end

    instrumenter_method :config

    instrumenter_method :mute, block: true
    instrumenter_method :unmute, block: true
    instrumenter_method :muted?

    # End a span
    instrumenter_method :done

    instrumenter_method :broken!

    # Temporarily disable
    instrumenter_method :disable, block: true

    # Runs the shutdown procedure in the background.
    # This should do little more than unsubscribe from all ActiveSupport::Notifications
    def spawn_shutdown_thread!
      @shutdown_thread || const_get(:LOCK).synchronize do
        @shutdown_thread ||= Thread.new { @instrumenter&.shutdown }
      end
    end
  end
end
