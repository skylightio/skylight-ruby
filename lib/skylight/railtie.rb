require 'skylight'
require 'rails'

module Skylight
  class Railtie < Rails::Railtie
    config.skylight = ActiveSupport::OrderedOptions.new

    # The environments in which skylight should be inabled
    config.skylight.environments = ['production']

    # The path to the configuration file
    config.skylight.config_path = "config/skylight.yml"

    initializer 'skylight.configure' do |app|
      if activate?
        if config = load_skylight_config(app)
          Instrumenter.start!(config)
          app.middleware.insert 0, Middleware

          Rails.logger.info "[SKYLIGHT] Skylight agent enabled"
        end
      end
    end

  private

    def load_skylight_config(app)
      path = config_path(app)
      path = nil unless File.exist?(path)

      unless tmp = app.config.paths['tmp'].first
        Rails.logger.warn "[SKYLIGHT] tmp directory missing from rails configuration"
        return nil
      end

      config = Config.load(path, Rails.env.to_s, ENV)
      config.logger = Rails.logger
      config['agent.sockfile_path'] = tmp
      config['normalizers.render.view_paths'] = app.config.paths["app/views"].existent
      config.validate!
      config

    rescue ConfigError => e
      Rails.logger.warn "[SKYLIGHT] #{e.message}; disabling Skylight agent"
      nil
    end

    def config_path(app)
      File.expand_path(config.skylight.config_path, app.root)
    end

    def environments
      Array(config.skylight.environments).map { |e| e && e.to_s }.compact
    end

    def activate?
      environments.include?(Rails.env.to_s)
    end
  end
end
