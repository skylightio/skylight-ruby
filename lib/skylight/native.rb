require "skylight/util/platform"

module Skylight
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

  # @api private
  # Whether or not the native extension is present
  @has_native_ext = false

  def self.native?
    @has_native_ext
  end

  def self.libskylight_path
    ENV["SKYLIGHT_LIB_PATH"] || File.expand_path("../native/#{Util::Platform.tuple}", __FILE__)
  end

  skylight_required = ENV.key?("SKYLIGHT_REQUIRED") && ENV["SKYLIGHT_REQUIRED"] !~ /^false$/i

  begin
    unless ENV.key?("SKYLIGHT_DISABLE_AGENT") && ENV["SKYLIGHT_DISABLE_AGENT"] !~ /^false$/i
      lib = "#{libskylight_path}/libskylight.#{Util::Platform.libext}"

      if File.exist?(lib)
        # First attempt to require the native extension
        require "skylight_native"

        # Attempt to link the dylib
        load_libskylight(lib)

        # If nothing was thrown, then the native extension is present
        @has_native_ext = true
      elsif skylight_required
        raise LoadError, "Cannot find native extensions in #{libskylight_path}"
      end
    end
  rescue RuntimeError => e
    # Old versions of OS X can have dlerrors, just treat it like a missing native
    raise if skylight_required || e.message !~ /dlerror/
  rescue LoadError
    raise if skylight_required
  end

  if Skylight.native?
    require 'skylight/util/clock'
    Util::Clock.use_native!
  else
    class Instrumenter
      def self.native_new(*_args)
        allocate
      end
    end
  end

  # @api private
  def self.check_install_errors(config)
    # Note: An unsupported arch doesn't count as an error.
    install_log = File.expand_path("../../ext/install.log", __dir__)

    if File.exist?(install_log) && File.read(install_log) =~ /ERROR/
      config.alert_logger.error \
        "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension failed to install. " \
        "Please check #{install_log} and notify support@skylight.io. " \
        "The missing extension will not affect the functioning of your application."
    end
  end

  # @api private
  def self.warn_skylight_native_missing(config)
    config.alert_logger.error \
      "[SKYLIGHT] [#{Skylight::VERSION}] The Skylight native extension for " \
      "your platform wasn't found. Supported operating systems are " \
      "Linux 2.6.18+ and Mac OS X 10.8+. The missing extension will not " \
      "affect the functioning of your application. If you are on a " \
      "supported platform, please contact support at support@skylight.io."
  end
end
