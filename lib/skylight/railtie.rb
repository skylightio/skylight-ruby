require 'skylight'
require 'rails'

module Skylight
  # @api private
  class Railtie < Rails::Railtie
    config.skylight = ActiveSupport::OrderedOptions.new

    # The environments in which skylight should be enabled
    config.skylight.environments = ['production']

    # The path to the configuration file
    config.skylight.config_path = "config/skylight.yml"

    # The probes to load
    #   net_http, action_controller, action_view, and grape are on by default
    #   Also available: excon, redis, sinatra, tilt, sequel
    config.skylight.probes = ['net_http', 'action_controller', 'action_view', 'grape']

    # The position in the middleware stack to place Skylight
    # Default is first, but can be `{ after: Middleware::Name }` or `{ before: Middleware::Name }`
    config.skylight.middleware_position = 0

    initializer 'skylight.configure' do |app|
      # Load probes even when agent is inactive to catch probe related bugs sooner
      load_probes

      config = load_skylight_config(app)

      if activate?
        if config
          begin
            if Instrumenter.start!(config)
              set_middleware_position(app, config)
              Rails.logger.info "[SKYLIGHT] [#{Skylight::VERSION}] Skylight agent enabled"
            else
              Rails.logger.info "[SKYLIGHT] [#{Skylight::VERSION}] Unable to start, see the Skylight logs for more details"
            end
          rescue ConfigError => e
            Rails.logger.error "[SKYLIGHT] [#{Skylight::VERSION}] #{e.message}; disabling Skylight agent"
          end
        end
      elsif Rails.env.development?
        unless UserConfig.instance.disable_dev_warning?
          log_warning config, "[SKYLIGHT] [#{Skylight::VERSION}] Running Skylight in development mode. No data will be reported until you deploy your app.\n" \
                                "(To disable this message for all local apps, run `skylight disable_dev_warning`.)"
        end
      elsif !Rails.env.test?
        unless UserConfig.instance.disable_env_warning?
          log_warning config, "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the #{Rails.env} environment but haven't added it to config.skylight.environments, so no data will be sent to skylight.io."
        end
      end
    end

  private

    def log_warning(config, msg)
      if config
        config.alert_logger.warn(msg)
      else
        Rails.logger.warn(msg)
      end
    end

    def existent_paths(paths)
      paths.respond_to?(:existent) ? paths.existent : paths.select { |f| File.exists?(f) }
    end

    def load_skylight_config(app)
      path = config_path(app)
      path = nil unless File.exist?(path)

      unless tmp = app.config.paths['tmp'].first
        Rails.logger.error "[SKYLIGHT] [#{Skylight::VERSION}] tmp directory missing from rails configuration"
        return nil
      end

      config = Config.load(file: path, environment: Rails.env.to_s)
      config[:root] = Rails.root

      configure_logging(config, app)

      config[:'daemon.sockdir_path'] ||= tmp
      config[:'normalizers.render.view_paths'] = existent_paths(app.config.paths["app/views"]) + [Rails.root.to_s]
      config
    end

    def configure_logging(config, app)
      if logger = app.config.skylight.logger
        config.logger = logger
      else
        # Configure the log file destination
        if log_file = app.config.skylight.log_file
          config['log_file'] = log_file
        elsif !config.key?('log_file') && !config.on_heroku?
          config['log_file'] = File.join(Rails.root, 'log/skylight.log')
        end

        # Configure the log level
        if level = app.config.skylight.log_level
          config['log_level'] = level
        elsif !config.key?('log_level')
          if level = app.config.log_level
            config['log_level'] = level
          end
        end
      end
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

    def load_probes
      probes = config.skylight.probes || []
      probes.each do |p|
        require "skylight/probes/#{p}"
      end
    end

    def middleware_position
      config.skylight.middleware_position.is_a?(Hash) ? config.skylight.middleware_position.symbolize_keys : config.skylight.middleware_position
    end

    def insert_middleware(app, config)
      if middleware_position.has_key?(:after)
        app.middleware.insert_after(middleware_position[:after], Skylight::Middleware, config: config)
      elsif middleware_position.has_key?(:before)
        app.middleware.insert_before(middleware_position[:before], Skylight::Middleware, config: config)
      else
        raise "The middleware position you have set is invalid. Please be sure `config.skylight.middleware_position` is set up correctly."
      end
    end

    def set_middleware_position(app, config)
      if middleware_position.is_a?(Integer)
        app.middleware.insert middleware_position, Middleware, config: config
      elsif middleware_position.is_a?(Hash) && middleware_position.keys.count == 1
        insert_middleware(app, config)
      elsif middleware_position.nil?
        app.middleware.insert 0, Middleware, config: config
      else
        raise "The middleware position you have set is invalid. Please be sure `config.skylight.middleware_position` is set up correctly."
      end
    end
  end
end
