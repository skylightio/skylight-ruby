require "skylight/core/version"
require "skylight/core/deprecation"

module Skylight
  module Core
    # Is this autoload even useful?
    autoload :Normalizers, "skylight/core/normalizers"
  end

  # Some methods exepected to be defined by the native code (OUTDATED)
  #
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

  require "active_support/notifications"

  require "skylight/core/config"
  require "skylight/core/user_config"
  require "skylight/core/gc"
  require "skylight/core/instrumenter"
  require "skylight/core/fanout"
  require "skylight/core/trace"
  require "skylight/core/vm/gc"
  require "skylight/core/util"
  require "skylight/core/middleware"
  require "skylight/core/sidekiq"
  require "skylight/core/subscriber"
  require "skylight/core/instrumentable"

  require "skylight/core/probes"

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
end
