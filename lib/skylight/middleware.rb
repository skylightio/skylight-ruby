module Skylight
  class Middleware
    attr_reader :instrumenter

    def initialize(app, instrumenter)
      @instrumenter = instrumenter
      @app = app
    end

    def call(env)
      instrumenter.trace("Rack") do
        @app.call(env)
      end
    end
  end
end
