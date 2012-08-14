module Tilde
  class Instrumenter

    attr_reader :worker

    def initialize
      @worker = Worker.start
    end

    def trace
      # If there already is a trace going on, then just continue
      if Thread.current[Trace::KEY]
        return yield
      end

      trace = Trace.new

      # Otherwise, make a new trace
      begin
        Thread.current[Trace::KEY] = trace
        yield
      ensure
        Thread.current[Trace::KEY] = nil
        begin
          process(trace)
        rescue Exception => e
          p [ :EXCEPTION, e ]
          puts e.backtrace
        end
      end
    end

  private

    def process(trace)
      worker.submit(trace)
    end

  end
end
