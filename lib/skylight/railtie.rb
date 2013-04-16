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

    initializer "skylight.sanity_check" do |app|
      checker = SanityChecker.new
      @problems = checker.smoke_test(config_path(app)) || checker.sanity_check(load_config(app))
      next unless @problems

      @problems.each do |group, problem_list|
        problem_list.each do |problem|
          puts "[SKYLIGHT] PROBLEM: #{group} #{problem}"
        end
      end
    end

    initializer "skylight.configure" do |app|
      if @problems
        puts "[SKYLIGHT] Skipping Skylight boot"
      else
        Rails.logger.debug "[SKYLIGHT] Installing middleware"
        app.middleware.insert 0, Middleware, load_config(app)
      end
    end

  private

    def environments
      Array(config.skylight.environments).map { |e| e && e.to_s }.compact
    end

    def config_path(app)
      path = config.skylight.config_path
      File.expand_path(path, app.root)
    end

    def load_config(app)
      @skylight_config ||= begin
        config = Config.load_from_yaml(config_path(app), ENV).tap do |c|
          c.logger = Rails.logger
        end

        config.normalizer.view_paths = app.config.paths["app/views"].existent
        config
      end
    rescue => e
      raise
      Rails.logger.error "[SKYLIGHT] #{e.message} (#{e.class}) - #{e.backtrace.first}"
    end

  end
end
