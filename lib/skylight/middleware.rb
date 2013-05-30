module Skylight
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      Skylight.trace "Rack" do |trace|
        trace.root 'app.rack.request' do
          @app.call(env)
        end
      end
    end
  end
end
