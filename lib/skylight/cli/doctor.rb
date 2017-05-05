module Skylight
  module CLI
    class Doctor < Thor::Group
      include Helpers

      desc "Run some basic tests to look out for common errors"

      def check_ssl
        say "Checking SSL"
        http = Util::HTTP.new(config)
        indent do
          req = http.get("/")
          if req.success?
            say "OK", :green
          else
            if req.exception.is_a?(Util::HTTP::StartError) && req.exception.original.is_a?(OpenSSL::SSL::SSLError)
              say "Failed to verify SSL certificate.", :red
              if Util::SSL.ca_cert_file?
                say "Certificates located at #{Util::SSL.ca_cert_file_or_default} may be out of date.", :yellow
                say "Please update your local certificates or try setting `SKYLIGHT_FORCE_OWN_CERTS=1` in your environment.", :yellow
              end
            else
              say "Unable to reach Skylight servers.", :red
            end
          end
        end
        say "\n"
      end

      def check_rails
        say "Checking for Rails"

        indent do
          if is_rails?
            say "Rails application detected", :green

            # Normally auto-loaded, but we haven't loaded Rails by the time Skylight is loaded
            require 'skylight/railtie'
            require rails_rb
          else
            say "No Rails application detected", :red
            abort "Currently `skylight doctor` only works with Rails applications"
          end
        end

        say "\n"
      end

      def check_native
        say "Checking for native agent"

        indent do
          if Skylight.native?
            say "Native agent installed", :green
          else
            say "Unable to load native extension", :yellow

            indent do
              install_log = File.expand_path("../../../ext/install.log", __FILE__)
              if File.exist?(install_log)
                File.readlines(install_log).each do |line|
                  say line, :red
                end
              else
                say "Reason unknown", :red
              end
            end

            abort
          end
        end

        say "\n"
      end

      def check_config
        say "Checking for valid configuration"

        indent do
          begin
            config.validate!
            say "Configuration is valid", :green
          rescue ConfigError => e
            say "Configuration is invalid", :red
            say "  #{e.message}", :red
            abort
          end
        end

        puts "\n"
      end

      def check_daemon
        say "Checking Skylight startup"

        indent do
          # Set this after we validate. It will give us more detailed information on start.
          logger = Logger.new("/dev/null") # Rely on `say` in the formatter instead
          # Log everything
          logger.level = Logger::DEBUG
          # Remove excess formatting
          logger.formatter = proc { |severity, datetime, progname, msg|
            msg = msg.sub("[SKYLIGHT] [#{Skylight::VERSION}] ", '')
            say "#{severity} - #{msg}" # Definitely non-standard
          }
          config.logger = logger

          config.set(:'daemon.lazy_start', false)

          started = Skylight.start!(config)

          if started
            say "Successfully started", :green
          else
            say "Failed to start", :red
            abort
          end

          say "Waiting for daemon... "

          # Doesn't start immediately
          tries = 0
          daemon_running = false
          while tries < 5
            `ps cax | grep skylightd`
            if $?.success?
              daemon_running = true
              break
            end

            tries += 1
            sleep 1
          end

          if daemon_running
            say "Success", :green
          else
            say "Failed", :red
          end
        end

        say "\n"
      end

      def status
        say "All checks passed!", :green
      end

      private

        # Overwrite the default helper method to load from Rails
        def config
          return @config if @config

          # MEGAHAX
          if is_rails?
            railtie = Skylight::Railtie.send(:new)
            @config = railtie.send(:load_skylight_config, Rails.application)
          else
            super
          end
        end
    end
  end
end