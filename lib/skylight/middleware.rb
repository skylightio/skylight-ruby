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
        trace.start(trace.start, "app.rack.request")
        instrumenter.gc.track do

          begin
            @app.call(env)
          ensure
            now = Util::Clock.now
            gc  = GC.time

            if gc > 0
              trace.start(now - gc, 'noise.gc')
              trace.stop(now)
            end

            trace.stop(now)
          end
        end
      end
    end
  end
end
