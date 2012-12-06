require 'skylight'
require 'rails'

module Skylight
  class Railtie < Rails::Railtie

    def instrumenter
      @instrumenter ||= Instrumenter.start!(config)
    end

    def config
      @config ||= Config.new
    end

    attr_writer :config

    initializer "skylight.configure" do |app|
      # Prepend the middleware
      app.middleware.insert 0, Middleware, instrumenter
    end

  end
end
