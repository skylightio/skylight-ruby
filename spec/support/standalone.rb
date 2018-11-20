require "tmpdir"

module SpecHelper
  module Standalone
    def self.with_dummy(dir = nil, &blk)
      unless dir
        tmpdir = Dir.mktmpdir
        dir = tmpdir
      end

      FileUtils.cp_r File.join(APP_ROOT, "spec/dummy"), dir
      Dir.chdir(File.join(dir, "dummy"), &blk)
    ensure
      FileUtils.remove_entry_secure tmpdir if tmpdir
    end

    def self.set_env(rails_version, port)
      # Gemfile
      ENV["RAILS_VERSION"] = rails_version
      ENV["SKYLIGHT_GEM_PATH"] = APP_ROOT

      # Skylight config
      ENV["SKYLIGHT_AUTH_URL"] = "http://127.0.0.1:#{port}/agent"
      ENV["SKYLIGHT_APP_CREATE_URL"] = "http://127.0.0.1:#{port}/apps"
      ENV["SKYLIGHT_MERGES_URL"] = "http://127.0.0.1:#{port}/merges"
      ENV["SKYLIGHT_VALIDATION_URL"] = "http://127.0.0.1:#{port}/agent/config"
      ENV["SKYLIGHT_AUTH_HTTP_DEFLATE"] = "false"
      ENV["SKYLIGHT_REPORT_HTTP_DISABLED"] = "true"
    end
  end

  def rails_version
    require "rails"
    Rails.version
  end

  def with_standalone(opts = {})
    # Make sure this is executed before we mess with the env, just in case

    begin
      opts[:rails_version] ||= rails_version
    rescue LoadError
      return
    end

    opts[:port] ||= 9292

    # This also resets other ENV vars that are set in the block
    rails_edge = ENV["RAILS_EDGE"]
    Bundler.with_clean_env do
      Standalone.with_dummy opts[:dir] do
        Standalone.set_env(opts[:rails_version], opts[:port])
        ENV["RAILS_EDGE"] = rails_edge if rails_edge
        yield
      end
    end
  end
end
