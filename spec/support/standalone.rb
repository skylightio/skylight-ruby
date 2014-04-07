require 'tmpdir'

module SpecHelper
  module Standalone

    def self.with_dummy(&blk)
      Dir.mktmpdir do |dir|
        FileUtils.cp_r File.join(APP_ROOT, "spec/dummy"), dir
        Dir.chdir(File.join(dir, "dummy"), &blk)
      end
    end

    def self.set_env(rails_version, port)
      # Gemfile
      ENV['RAILS_VERSION'] = rails_version
      ENV['SKYLIGHT_GEM_PATH'] = APP_ROOT

      # Skylight config
      ENV['SKYLIGHT_ME_CREDENTIALS_PATH'] = File.expand_path("../.skylight")
      ENV['SKYLIGHT_ACCOUNTS_HOST']    = "localhost"
      ENV['SKYLIGHT_ACCOUNTS_PORT']    = port.to_s
      ENV['SKYLIGHT_ACCOUNTS_SSL']     = "false"
      ENV['SKYLIGHT_ACCOUNTS_DEFLATE'] = "false"
    end
  end

  def rails_version
    require 'rails'
    Rails.version
  end

  def with_standalone(opts={})
    # Make sure this is executed before we mess with the env, just in case
    opts[:rails_version] ||= rails_version
    opts[:port] ||= 9292

    # This also resets other ENV vars that are set in the block
    Bundler.with_clean_env do
      Standalone.with_dummy do
        Standalone.set_env(opts[:rails_version], opts[:port])
        yield
      end
    end
  end
end