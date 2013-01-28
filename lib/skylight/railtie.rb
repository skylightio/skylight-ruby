require 'skylight'
require 'rails'

module Skylight
  class Railtie < Rails::Railtie
    # The environments in which skylight should be inabled
    config.environments = ['production']

    # The path to the configuration file
    config.skylight_config_path = "config/skylight.yml"

    attr_accessor :instrumenter

    initializer "skylight.configure" do |app|
      if self.instrumenter = load_instrumenter
        app.middleware.insert 0, Middleware, instrumenter
      end
    end

  private

    def environments
      Array(config.environments).map { |e| e && e.to_s }.compact
    end

    def load_instrumenter
      if environments.include?(Rails.env.to_s)
        if c = load_config
          Instrumenter.start!(c)
        end
      end
    # Paranoia
    rescue
      nil
    end

    def load_config
      unless path = config.skylight_config_path
        Rails.logger.warn "[SKYLIGHT] Path to config YAML file unset"
        return
      end

      path = File.expand_path(Rails.root.join(path))

      unless File.exist?(path)
        Rails.logger.warn "[SKYLIGHT] Config does not exist at `#{path}`"
      end

      ret = Config.load_from_yaml(path)

      unless ret.authentication_token
        Rails.logger.warn "[SKYLIGHT] Config does not include an authentication token"
        return
      end

      ret
    rescue => e
      Rails.logger.error "[SKYLIGHT] #{e.message} (#{e.class}) - #{e.backtrace.first}"
    end

  end
end
