$:.unshift File.expand_path('../vendor/cli', __FILE__)

require 'skylight'
require 'thor'
require 'yaml'
require 'highline'
require 'active_support/inflector'

module Skylight
  # @api private
  class CLI < Thor

    desc "setup TOKEN", "Sets up a new app using the provided token"
    def setup(token=nil)
      if File.exist?(config_path)
        say "Your app is already on Skylight. http://www.skylight.io", :green
        return
      end

      unless token
        api.authentication = login
      end

      res = api.create_app(app_name, token)

      config[:application]    = res.get('app.id')
      config[:authentication] = res.get('app.token')
      config.write(config_path)

      say "Congratulations. Your application is on Skylight! http://www.skylight.io", :green
      say <<-OUT

The application was registered for you and we generated a config file
containing your API token at:

  #{relative_config_path}

The next step is for you to deploy your application to production. The
easiest way is to just commit the config file to your source control
repository and deploy from there. You can learn more about the process at:

  http://docs.skylight.io/getting-set-up/#deployment

If you want to specify the authentication token as an environment variable,
you should set the `SKYLIGHT_AUTHENTICATION` variable to:

  #{config[:authentication]}

      OUT
    rescue Api::CreateFailed => e
      say "Could not create the application", :red
      say e.to_s, :yellow
    rescue Interrupt
    end

    desc "disable_dev_warning", "Disables warning about running Skylight in development mode for all local apps"
    def disable_dev_warning
      user_config.disable_dev_warning = true
      user_config.save

      say "Development mode warning disabled", :green
    end

  private

    def app_name
      @app_name ||=
        begin
          name = nil

          if File.exist?("config/application.rb")
            # This looks like a Rails app, lets make sure we have the railtie loaded
            # skylight.rb checks for Rails, but when running the CLI, Skylight loads before Rails does
            begin
              require "skylight/railtie"
            rescue LoadError => e
              error "Unable to load Railtie. Please notify support@skylight.io."
            end

            # Get the name in a process so that we don't pollute our environment here
            # This is especially important since users may have things like WebMock that
            # will prevent us from communicating with the Skylight API
            begin
              namefile = Tempfile.new('skylight-app-name')
              # Windows appears to need double quotes for `rails runner`
              `rails runner "File.open('#{namefile.path}', 'w') {|f| f.write(Rails.application.class.name) rescue '' }"`
              name = namefile.read.split("::").first.underscore.titleize
              name = nil if name.empty?
            rescue => e
              if ENV['DEBUG']
                puts e.class.name
                puts e.to_s
                puts e.backtrace.join("\n")
              end
            ensure
              namefile.close
              namefile.unlink
            end

            unless name
              warn "Unable to determine Rails application name. Using directory name."
            end
          end

          unless name
            name = File.basename(File.expand_path('.')).titleize
          end

          name
        end
    end

    def login
      say "Please enter your email and password below or get a token from https://www.skylight.io/app/setup.", :cyan

      10.times do
        email    = highline.ask("Email: ")
        password = highline.ask("Password: ") { |q| q.echo = "*" }

        if token = api.login(email, password)
          return token
        end

        say "Sorry. That email and password was invalid. Please try again", :red
        puts
      end

      say "Could not login", :red
      return
    end

    def relative_config_path
      'config/skylight.yml'
    end

    def config_path
      File.expand_path(relative_config_path)
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

    def user_config
      UserConfig.instance
    end

  end
end
