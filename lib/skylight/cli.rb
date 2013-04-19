require "skylight"
require "thor"
require "highline"

module Skylight
  class CLI < Thor
    desc "create", "Create a new app"
    def create
      if !SanityChecker.new.smoke_test(File.expand_path("config/skylight.yml"))
        say "Your app is already on Skylight. http://www.skylight.io", :green
        return
      end

      token = load_credentials
      config = http_config

      response = Util::HTTP.new(config).create_app(token, app_name)["app"]

      config.app_id = response["id"]
      config.authentication_token = response["token"]

      config.yaml_file = File.expand_path("config/skylight.yml")

      config.save

      say "Congratulations. Your application is on Skylight! http://www.skylight.io", :green
    end

  private
    def user_settings
      File.expand_path("~/.skylight")
    end

    def http_config
      @http_config ||= Config.new do |c|
        c.host = "www.skylight.io"
        c.port = 443
        c.ssl = true
        c.deflate = false
      end
    end

    def load_credentials
      if credentials?
        return YAML.load_file(user_settings)["token"]
      end

      token = nil

      loop do
        h = HighLine.new
        username = h.ask("Username: ")
        password = h.ask("Password: ") { |q| q.echo = "*" }

        response = Util::HTTP.new(http_config).auth(username, password)
        if response["authenticated"] == false
          say "Sorry. That username and password was invalid. Please try again", :red
          puts
        else
          token = response["token"]
          break
        end
      end

      File.open(user_settings, "w") do |file|
        file.puts YAML.dump("token" => token)
      end

      token
    end

    def credentials?
      !SanityChecker.new.user_credentials(user_settings)
    end

    def app_name
      require "./config/application"
      Rails.application.class.name.split("::").first.underscore
    end
  end
end
