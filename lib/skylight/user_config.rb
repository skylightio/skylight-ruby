require 'yaml'

module Skylight
  class UserConfig

    attr_accessor :disable_dev_warning, :disable_env_warning

    def self.instance
      @instance ||= new
    end

    def initialize
      reload
    end

    def file_path
      File.expand_path(ENV["SKYLIGHT_USER_CONFIG_PATH"] || "~/.skylight")
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
