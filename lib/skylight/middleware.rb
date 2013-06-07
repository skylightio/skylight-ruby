module Skylight
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      Skylight.trace "Rack", 'app.rack.request' do |trace|
        @app.call(env)
      end
    end
  end
end
