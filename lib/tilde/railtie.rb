require 'tilde'
require 'rails'

module Tilde
  class Railtie < Rails::Railtie

    def instrumenter
      @instrumenter ||= Instrumenter.new
    end

    initializer "tilde.configure" do |app|
      # Register the notifications subscriber
      Subscriber.register!

      # Prepend the middleware
      app.middleware.insert 0, Middleware, instrumenter
    end

  end
end
