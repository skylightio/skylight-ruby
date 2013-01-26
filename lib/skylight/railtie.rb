require 'skylight'
require 'rails'

module Skylight
  class Railtie < Rails::Railtie
    config.skylight = Config.new

    def instrumenter
      @instrumenter ||= Instrumenter.start!(config.skylight)
    # Paranoia
    rescue
      nil
    end

    initializer "skylight.configure" do |app|
      # Paranoia
      if instrumenter
        # Prepend the middleware
        app.middleware.insert 0, Middleware, instrumenter
      end
    end

  end
end
