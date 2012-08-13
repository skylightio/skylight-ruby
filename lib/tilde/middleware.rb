module Tilde
  class Middleware
    def initialize(app, instrumenter)
      @instrumenter = instrumenter
      @app = app
    end

    def call(env)
      @instrumenter.trace { @app.call(env) }
    end
  end
end
