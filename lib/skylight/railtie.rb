require 'skylight'
require 'rails'

module Skylight
  class Railtie < Rails::Railtie
    config.skylight = ActiveSupport::OrderedOptions.new

    # The environments in which skylight should be inabled
    config.skylight.environments = ['production']

    # The path to the configuration file
    config.skylight.config_path = "config/skylight.yml"

    attr_accessor :instrumenter

    initializer "skylight.configure" do |app|
      if self.instrumenter = load_instrumenter
        Rails.logger.debug "[SKYLIGHT] Installing middleware"
        app.middleware.insert 0, Middleware, instrumenter
      end
    end

  private

    def environments
      Array(config.skylight.environments).map { |e| e && e.to_s }.compact
    end

    def load_instrumenter
      if environments.include?(Rails.env.to_s)
        if c = load_config
          Rails.logger.debug "[SKYLIGHT] Starting instrumenter"
          Instrumenter.start!(c)
        end
      end
    # Paranoia
    rescue
      nil
    end

    def load_config
      unless path = config.skylight.config_path
        Rails.logger.warn "[SKYLIGHT] Path to config YAML file unset"
        return
      end

      path = File.expand_path(path, Rails.root)

      unless File.exist?(path)
        Rails.logger.warn "[SKYLIGHT] Config does not exist at `#{path}`"
        return
      end

      ret = Config.load_from_yaml(path)

      unless ret.authentication_token
        Rails.logger.warn "[SKYLIGHT] Config does not include an authentication token"
        return
      end

      ret.logger = Rails.logger

      ret
    rescue => e
      Rails.logger.error "[SKYLIGHT] #{e.message} (#{e.class}) - #{e.backtrace.first}"
    end

  end
end
