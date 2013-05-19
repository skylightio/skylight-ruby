module Skylight
  class Instrumenter
    include Util::Logging

    def trace(endpoint = nil)
      # Ignore everything unless the instrumenter has been started
      unless @started
        return yield
      end

      # If a trace is already in progress, continue with that one
      if Trace.current
        return yield
      end

      trace = Trace.new(endpoint)

      begin
        Thread.current = trace
        yield trace
      ensure
        Trace.current = nil

        begin
          trace.commit
          process(trace)
        rescue Exception => e
          error e
        end
      end
    end

  private

    def process(trace)
      p trace
    end

  end
end
