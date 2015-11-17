require 'skylight/util/platform'

module Skylight
  # @api private
  # Whether or not the native extension is present
  @@has_native_ext = false

  def self.native?
    @@has_native_ext
  end

  def self.libskylight_path
    ENV['SKYLIGHT_LIB_PATH'] || File.expand_path("../native/#{Util::Platform.tuple}", __FILE__)
  end

  skylight_required = ENV.key?("SKYLIGHT_REQUIRED") && ENV['SKYLIGHT_REQUIRED'] !~ /^false$/i

  begin
    unless ENV.key?("SKYLIGHT_DISABLE_AGENT") && ENV['SKYLIGHT_DISABLE_AGENT'] !~ /^false$/i
      lib = "#{libskylight_path}/libskylight.#{Util::Platform.libext}"

      if File.exist?(lib)
        # First attempt to require the native extension
        require "skylight_native"

        # Attempt to link the dylib
        load_libskylight(lib)

        # If nothing was thrown, then the native extension is present
        @@has_native_ext = true
      elsif skylight_required
        raise LoadError, "Cannot find native extensions in #{libskylight_path}"
      end
    end
  rescue RuntimeError => e
    # Old versions of OS X can have dlerrors, just treat it like a missing native
    raise if skylight_required || e.message !~ /dlerror/
  rescue LoadError => e
    raise if skylight_required
  end

  unless Skylight.native?
    class Instrumenter
      def self.native_new(*args)
        allocate
      end
    end
  end

  # @api private
  def self.check_install_errors(config)
    # Note: An unsupported arch doesn't count as an error.
    install_log = File.expand_path("../../../ext/install.log", __FILE__)

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
