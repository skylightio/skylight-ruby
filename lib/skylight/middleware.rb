module Skylight
  class Middleware
    def self.new(app, config, *)
      return app unless config
      super
    end

    def initialize(app, config, instrumenter_class=Instrumenter)
      @app = app
      @config = config
      @instrumenter_class = instrumenter_class
    end

    def call(env)
      instrumenter.trace("Rack") do
        ActiveSupport::Notifications.instrument("app.rack.request") do
          @app.call(env)
        end
      end
    end

  private
    LOCK = Mutex.new

    def instrumenter
      return @instrumenter if defined?(@instrumenter)

      LOCK.synchronize do
        return @instrumeter if defined?(@instrumenter)
        @instrumenter = @instrumenter_class.start!(@config)
        return @instrumenter
      end
    rescue Exception
      @instrumenter = stub
    end

    def stub
      Class.new do
        def trace(*)
          yield
        end
      end.new
    end
  end
end
