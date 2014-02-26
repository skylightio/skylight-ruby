require 'skylight'
require 'rails'

module Skylight
  class Railtie < Rails::Railtie
    config.skylight = ActiveSupport::OrderedOptions.new

    # The environments in which skylight should be inabled
    config.skylight.environments = ['production']

    # The path to the configuration file
    config.skylight.config_path = "config/skylight.yml"

    # The probes to load
    config.skylight.probes = []

    initializer 'skylight.configure' do |app|
      if activate?
        load_probes

        if config = load_skylight_config(app)
          Instrumenter.start!(config)
          app.middleware.insert 0, Middleware

          puts "[SKYLIGHT] [#{Skylight::VERSION}] Skylight agent enabled"
        end
      elsif !Rails.env.test? && Rails.env.development?
        puts "[SKYLIGHT] [#{Skylight::VERSION}] You are running in the #{Rails.env} environment but haven't added it to config.skylight.environments, so no data will be sent to skylight.io."
      end
    end

  private

    def existent_paths(paths)
      paths.respond_to?(:existent) ? paths.existent : paths.select { |f| File.exists?(f) }
    end

    def load_skylight_config(app)
      path = config_path(app)
      path = nil unless File.exist?(path)

      unless tmp = app.config.paths['tmp'].first
        puts "[SKYLIGHT] [#{Skylight::VERSION}] tmp directory missing from rails configuration"
        return nil
      end

      config = Config.load(path, Rails.env.to_s, ENV)
      config['root'] = Rails.root

      configure_logging(config, app)

      config['agent.sockfile_path'] = tmp
      config['normalizers.render.view_paths'] = existent_paths(app.config.paths["app/views"]) + [Rails.root.to_s]
      config.validate!
      config

    rescue ConfigError => e
      puts "[SKYLIGHT] [#{Skylight::VERSION}] #{e.message}; disabling Skylight agent"
      nil
    end

    def configure_logging(config, app)
      if logger = app.config.skylight.logger
        config.logger = logger
      else
        # Configure the log file destination
        if log_file = app.config.skylight.log_file
          config['log_file'] = log_file
        elsif !config.key?('log_file')
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
  end
end
