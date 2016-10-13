require 'yaml'

module Skylight
  class UserConfig

    attr_accessor :disable_dev_warning

    def self.instance
      @instance ||= new
    end

    def initialize
      reload
    end

    def file_path
      unless @file_path
        config_path = ENV.fetch("SKYLIGHT_USER_CONFIG_PATH") do
          require "etc"
          home_dir = File.expand_path("~") || Etc.getpwuid.dir || (ENV["USER"] && File.expand_path("~#{ENV['USER']}"))
          if home_dir
            File.join(home_dir, ".skylight")
          else
            raise KeyError, "SKYLIGHT_USER_CONFIG_PATH must be defined since the home directory cannot be inferred"
          end
        end
        @file_path = File.expand_path(config_path)
      end
      @file_path
    end

    def disable_dev_warning?
      disable_dev_warning
    end

    def reload
      config = File.exist?(file_path) ? YAML.load_file(file_path) : false
      return unless config

      self.disable_dev_warning = !!config['disable_dev_warning']
    end

    def save
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'w') do |f|
        f.puts YAML.dump(to_hash)
      end
    end

    def to_hash
      {
        'disable_dev_warning' => disable_dev_warning
      }
    end

  end
end
