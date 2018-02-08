require 'yaml'
require 'skylight/core/errors'

module Skylight::Core
  class UserConfig

    attr_accessor :disable_dev_warning, :disable_env_warning

    def initialize(config)
      @config = config
      @file_path = nil
      reload
    end

    def file_path
      return @file_path if @file_path

      config_path = @config[:user_config_path] || begin
        require "etc"
        home_dir = ENV['HOME'] || Etc.getpwuid.dir || (ENV["USER"] && File.expand_path("~#{ENV['USER']}"))
        if home_dir
          File.join(home_dir, ".skylight")
        else
          raise ConfigError, "The Skylight `user_config_path` must be defined since the home directory cannot be inferred"
        end
      end

      @file_path = File.expand_path(config_path)
    end

    def disable_dev_warning?
      disable_dev_warning
    end

    def disable_env_warning?
      disable_env_warning
    end

    def reload
      config = File.exist?(file_path) ? YAML.load_file(file_path) : false
      return unless config

      self.disable_dev_warning = !!config['disable_dev_warning']
      self.disable_env_warning = !!config['disable_env_warning']
    end

    def save
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'w') do |f|
        f.puts YAML.dump(to_hash)
      end
    end

    def to_hash
      {
        'disable_dev_warning' => disable_dev_warning,
        'disable_env_warning' => disable_env_warning
      }
    end

  end
end
