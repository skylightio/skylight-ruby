$:.unshift File.expand_path('../vendor/cli', __FILE__)

require 'skylight'
require 'thor'
require 'yaml'
require 'highline'
require 'active_support/inflector'

module Skylight
  class CLI < Thor

    desc "setup", "Sets up a new app"
    def setup
      if File.exist?(config_path)
        say "Your app is already on Skylight. http://www.skylight.io", :green
        return
      end

      api.authentication = load_credentials

      unless res = api.create_app(app_name)
        say "Could not create the application", :red
        return
      end

      config[:application]    = res.get('app.id')
      config[:authentication] = res.get('app.token')
      config.write(config_path)

      say "Congratulations. Your application is on Skylight! http://www.skylight.io", :green
      say <<-OUT

The application was registered for you and we generated an config file
containing your API token at:

  #{relative_config_path}

The next step is for you to deploy your application to production. The
easiest way is to just commit the config file to your source control
repository and deploy from there. You can learn more about the process at:

  http://docs.skylight.io/getting-started/#deploy

      OUT
    rescue Interrupt
    end

  private

    def app_name
      @app_name ||=
        begin
          if File.exist?("config/application.rb")
            require "./config/application"
            Rails.application.class.name.split("::").first.underscore.humanize
          else
            File.basename(File.expand_path('.')).humanize
          end
        end
    end

    def load_credentials
      load_credentials_from_file || login
    end

    def login
      10.times do
        email    = highline.ask("Email: ")
        password = highline.ask("Password: ") { |q| q.echo = "*" }

        if token = api.login(email, password)
          # Write the token
          FileUtils.mkdir_p(File.dirname(credentials_path))
          File.open(credentials_path, 'w') do |f|
            f.puts YAML.dump('token' => token)
          end

          return token
        end

        say "Sorry. That email and password was invalid. Please try again", :red
        puts
      end

      say "Could not login", :red
      return
    end

    def load_credentials_from_file
      return unless File.exist?(credentials_path)
      return unless yaml = YAML.load_file(credentials_path)
      yaml['token']
    end

    def relative_config_path
      'config/skylight.yml'
    end

    def config_path
      File.expand_path(relative_config_path)
    end

    def credentials_path
      File.expand_path(config[:'me.credentials_path'])
    end

    def api
      @api ||= Api.new(config)
    end

    def highline
      @highline ||= HighLine.new
    end

    def config
      # Calling .load checks ENV variables
      @config ||= Config.load
    end

  end
end
