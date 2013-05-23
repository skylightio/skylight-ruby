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
      @instrumenter.trace("Rack") do |trace|
        trace.root 'app.rack.request' do
          @app.call(env)
        end
      end
    end
  end
end
