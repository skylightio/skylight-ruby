$:.unshift File.expand_path('../vendor/cli', __FILE__)

require 'skylight'
require 'thor'
require 'yaml'
require 'highline'
require 'active_support/inflector'

require 'skylight/cli/helpers'
require 'skylight/cli/doctor'

module Skylight
  module CLI
    # @api private
    class Base < Thor
      include Helpers

      register(Doctor, "doctor", "doctor", "Run some basic tests to look out for common problems")

      desc "setup TOKEN", "Sets up a new app using the provided token"
      def setup(token)
        if File.exist?(config_path)
          say <<-OUT, :green
A config/skylight.yml already exists for your application.

Visit your app at https://www.skylight.io/app or remove config/skylight.yml
to set it up as a new app in Skylight.
          OUT
          return
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
        say "Could not create the application. Please run `skylight doctor` for diagnostics.", :red
        say e.to_s, :yellow
      rescue Interrupt
      end

      desc "disable_dev_warning", "Disables warning about running Skylight in development mode for all local apps"
      def disable_dev_warning
        user_config.disable_dev_warning = true
        user_config.save

        say "Development mode warning disabled", :green
      end

      desc "disable_env_warning", "Disables warning about running Skylight in environments not defined in config.skylight.environments"
      def disable_env_warning
        user_config.disable_env_warning = true
        user_config.save

        say "Environment warning disabled", :green
      end

    private

      def app_name
        @app_name ||=
          begin
            name = nil

            if is_rails?
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

      # Is this duplicated?
      def relative_config_path
        'config/skylight.yml'
      end

      def config_path
        File.expand_path(relative_config_path)
      end

      def api
        config.api
      end

      def user_config
        UserConfig.instance
      end

    end
  end
end
