module Skylight
  class Middleware
    def self.new(app, config, *)
      return app unless config
      super
    end

    def initialize(app, config, instrumenter=nil)
      @app = app
      @config = config
      @instrumenter = instrumenter
    end

    def call(env)
      instrumenter.trace("Rack") do
        ActiveSupport::Notifications.instrument("rack.request") do
          @app.call(env)
        end
      end
    end

  private
    LOCK = Mutex.new

    def instrumenter
      return @instrumenter if @instrumenter

      LOCK.synchronize do
        return @instrumeter if @instrumenter
        @instrumenter = Instrumenter.start!(@config)
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
      end
    end
  end
end
