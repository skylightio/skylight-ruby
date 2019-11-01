require "skylight/version"
require "skylight/fanout"
require "skylight/trace"
require "skylight/instrumentable"
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

  include Instrumentable

  def self.instrumenter_class
    Instrumenter
  end

  def self.config_class
    Config
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
