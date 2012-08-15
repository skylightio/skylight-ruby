require 'tilde'
require 'rails'

module Tilde
  class Railtie < Rails::Railtie

    def instrumenter
      @instrumenter ||= Instrumenter.start!(config)
    end

    def config
      @config ||= Config.new
    end

    initializer "tilde.configure" do |app|
      # Prepend the middleware
      app.middleware.insert 0, Middleware, instrumenter
    end

  end
end
