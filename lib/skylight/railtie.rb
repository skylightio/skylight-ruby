require "skylight"
require "rails"

module Skylight
  # @api private
  class Railtie < Rails::Railtie
    # rubocop:disable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs
    def self.root_key; :skylight end
    def self.middleware_class; Middleware end
    def self.gem_name; "Skylight" end
    def self.log_file_name; "skylight" end
    def self.namespace; Skylight end
    def self.version; Skylight::VERSION end
    # rubocop:enable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs

    config.skylight = ActiveSupport::OrderedOptions.new

    # The environments in which skylight should be enabled
    config.skylight.environments = ["production"]

    # The path to the configuration file
    config.skylight.config_path = "config/skylight.yml"

    # The probes to load
    #   net_http, action_controller, action_dispatch, action_view, and middleware are on by default
    #   See https://www.skylight.io/support/getting-more-from-skylight#available-instrumentation-options
    #   for a full list.
    config.skylight.probes = %w[net_http action_controller action_dispatch action_view middleware active_job_enqueue]

    # The position in the middleware stack to place Skylight
    # Default is first, but can be `{ after: Middleware::Name }` or `{ before: Middleware::Name }`
    config.skylight.middleware_position = 0

    initializer "skylight.configure" do |app|
      run_initializer(app)
    end

    private

      # We must have an opt-in signal
      def show_worker_activation_warning(sk_config)
        reasons = []
        reasons << "the 'active_job' probe is enabled" if sk_rails_config.probes.include?("active_job")
        reasons << "the 'delayed_job' probe is enabled" if sk_rails_config.probes.include?("delayed_job")
        reasons << "SKYLIGHT_ENABLE_SIDEKIQ is set" if sk_config.enable_sidekiq?

        return if reasons.empty?

        sk_config.logger.warn("Activating Skylight for Background Jobs because #{reasons.to_sentence}")
      end

      def log_prefix
        "[#{self.class.gem_name.upcase}] [#{self.class.version}]"
      end

      def development_warning
        "#{log_prefix} Running #{self.class.gem_name} in development mode. No data will be reported until you deploy your app.\n" \
          "(To disable this message for all local apps, run `skylight disable_dev_warning`.)"
      end

      def run_initializer(app)
        # Load probes even when agent is inactive to catch probe related bugs sooner
        load_probes

        config = load_skylight_config(app)

        if activate?(config)
          if config
            if self.class.namespace.start!(config)
              set_middleware_position(app, config)
              Rails.logger.info "#{log_prefix} #{self.class.gem_name} agent enabled"
            else
              Rails.logger.info "#{log_prefix} Unable to start, see the #{self.class.gem_name} logs for more details"
            end
          end
        elsif Rails.env.development?
          # FIXME: The CLI isn't part of core so we should change this message
          unless config.user_config.disable_dev_warning?
            log_warning config, development_warning
          end
        elsif !Rails.env.test?
          unless config.user_config.disable_env_warning?
            log_warning config, "#{log_prefix} You are running in the #{Rails.env} environment but haven't added it to config.#{self.class.root_key}.environments, so no data will be sent to #{config.class.service_name} servers."
          end
        end
      rescue Skylight::ConfigError => e
        Rails.logger.error "#{log_prefix} #{e.message}; disabling #{self.class.gem_name} agent"
      end

      def log_warning(config, msg)
        if config
          config.alert_logger.warn(msg)
        else
          Rails.logger.warn(msg)
        end
      end

      def existent_paths(paths)
        paths.respond_to?(:existent) ? paths.existent : paths.select { |f| File.exist?(f) }
      end

      def load_skylight_config(app)
        path = config_path(app)
        path = nil unless File.exist?(path)

        unless (tmp = app.config.paths["tmp"].first)
          Rails.logger.error "#{log_prefix} tmp directory missing from rails configuration"
          return nil
        end

        config = Config.load(file: path, environment: Rails.env.to_s)
        config[:root] = Rails.root

        configure_logging(config, app)

        config[:'daemon.sockdir_path'] ||= tmp
        config[:'normalizers.render.view_paths'] = existent_paths(app.config.paths["app/views"]) + [Rails.root.to_s]

        if config[:report_rails_env]
          config[:env] ||= Rails.env.to_s
        end

        config
      end

      def configure_logging(config, app)
        if (logger = sk_rails_config(app).logger)
          config.logger = logger
        else
          # Configure the log file destination
          if (log_file = sk_rails_config(app).log_file)
            config["log_file"] = log_file
          elsif !config.key?("log_file") && !config.on_heroku?
            config["log_file"] = File.join(Rails.root, "log/#{self.class.log_file_name}.log")
          end

          # Configure the log level
          if (level = sk_rails_config(app).log_level)
            config["log_level"] = level
          elsif !config.key?("log_level")
            if (level = app.config.log_level)
              config["log_level"] = level
            end
          end
        end
      end

      def config_path(app)
        File.expand_path(sk_rails_config.config_path, app.root)
      end

      def environments
        Array(sk_rails_config.environments).map { |e| e&.to_s }.compact
      end

      def activate?(sk_config)
        return false unless sk_config

        key = "#{Config.env_prefix}ENABLED"
        activate =
          if ENV.key?(key)
            ENV[key] !~ /^false$/i
          else
            environments.include?(Rails.env.to_s)
          end

        show_worker_activation_warning(sk_config) if activate

        activate
      end

      def load_probes
        probes = sk_rails_config.probes || []
        Skylight::Probes.probe(*probes)
      end

      def middleware_position
        sk_rails_config.middleware_position.is_a?(Hash) ? sk_rails_config.middleware_position.symbolize_keys : sk_rails_config.middleware_position
      end

      def insert_middleware(app, config)
        if middleware_position.key?(:after)
          app.middleware.insert_after(middleware_position[:after], self.class.middleware_class, config: config)
        elsif middleware_position.key?(:before)
          app.middleware.insert_before(middleware_position[:before], self.class.middleware_class, config: config)
        else
          raise "The middleware position you have set is invalid. Please be sure `config.#{self.class.root_key}.middleware_position` is set up correctly."
        end
      end

      def set_middleware_position(app, config)
        if middleware_position.is_a?(Integer)
          app.middleware.insert middleware_position, self.class.middleware_class, config: config
        elsif middleware_position.is_a?(Hash) && middleware_position.keys.count == 1
          insert_middleware(app, config)
        elsif middleware_position.nil?
          app.middleware.insert 0, self.class.middleware_class, config: config
        else
          raise "The middleware position you have set is invalid. Please be sure `config.#{self.class.root_key}.middleware_position` is set up correctly."
        end
      end

      def sk_rails_config(target = self)
        target.config.send(self.class.root_key)
      end
  end
end
