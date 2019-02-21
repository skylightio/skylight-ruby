require "skylight/core/railtie"

module Skylight
  class Railtie < Rails::Railtie
    include Skylight::Core::Railtie

    # rubocop:disable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs
    def self.config_class; Skylight::Config end
    def self.middleware_class; Skylight::Middleware end
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

      def activate?(sk_config)
        return false unless super && sk_config
        activate_for_worker?(sk_config) || activate_for_web?(sk_config)
      end

      # We must have an opt-in signal
      def activate_for_worker?(sk_config)
        return unless sk_config.worker_context?

        reasons = []
        reasons << "the 'active_job' probe is enabled" if sk_rails_config.probes.include?("active_job")
        reasons << "SKYLIGHT_ENABLE_SIDEKIQ is set" if sk_config.enable_sidekiq?

        return if reasons.empty?

        sk_config.logger.warn("Activating Skylight for Background Jobs because #{reasons.to_sentence}")
        true
      end

      def activate_for_web?(sk_config)
        sk_config.web_context?
      end

      def development_warning
        super + "\n(To disable this message for all local apps, run `skylight disable_dev_warning`.)"
      end

      def load_skylight_config(app)
        super.tap do |sk_config|
          if sk_config && sk_config[:report_rails_env]
            sk_config[:env] ||= Rails.env.to_s
          end
        end
      end
  end
end
