require "yaml"

module Skylight
  class SanityChecker
    def initialize(app, config)
      @app = app
      @config = config
      @problems = Hash.new { |h,k| h[k] = [] }
    end

    def sanity_check
      check_config_exists
      check_config_contents
      @problems
    end

  private
    def yaml_file
      File.join(@app, "config/skylight.yml")
    end

    def check_config_exists
      return if File.exist?(yaml_file)
      @problems["skylight.yml"] << "does not exist"
    end

    def check_config_contents
      return unless File.exist?(yaml_file)

      unless @config.app_id
        @problems["skylight.yml"] << "does not contain an app id - please run `skylight create`"
      end

      unless @config.authentication_token
        @problems["skylight.yml"] << "does not contain an app token - please run `skylight create`"
      end
    end
  end
end
