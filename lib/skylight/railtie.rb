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
      if environments.include?(Rails.env.to_s)
        config = load_config(app)

        if good_to_go?(app, config)
          @instrumenter = Instrumenter.new(config)

          Rails.logger.debug "[SKYLIGHT] Installing middleware"
          app.middleware.insert 0, Middleware, @instrumenter
        else
          puts "[SKYLIGHT] Skipping Skylight boot"
        end
      end
    end

  private

    def good_to_go?(app, config)
      unless problems = check_for_problems(app, config)
        return true
      end

      problems.each do |group, problem_list|
        problem_list.each do |problem|
          puts "[SKYLIGHT] PROBLEM: #{group} #{problem}"
        end
      end

      false
    end

    def check_for_problems(app, config)
      checker = SanityChecker.new
      checker.smoke_test(config_path(app)) || checker.sanity_check(config)
    end

    def load_config(app)
        config = Config.load_from_yaml(config_path(app), ENV).tap do |c|
          c.logger = Rails.logger
        end

        config.normalizer.view_paths = app.config.paths["app/views"].existent
        config
    rescue => e
      raise
      Rails.logger.error "[SKYLIGHT] #{e.message} (#{e.class}) - #{e.backtrace.first}"
    end

    def environments
      Array(config.skylight.environments).map { |e| e && e.to_s }.compact
    end

    def config_path(app)
      path = config.skylight.config_path
      File.expand_path(path, app.root)
    end


  end
end
