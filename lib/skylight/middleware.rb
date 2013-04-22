module Skylight
  class Middleware

    def self.new(app, instrumenter, *)
      return app unless instrumenter
      super
    end

    def initialize(app, instrumenter)
      @app = app
      @instrumenter = instrumenter
    end

    def call(env)
      @instrumenter.start!

      @instrumenter.trace("Rack") do
        ActiveSupport::Notifications.instrument("app.rack.request") do
          @app.call(env)
        end
      end
    end
  end
end
