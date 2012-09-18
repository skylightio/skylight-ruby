module Tilde
  class Instrumenter
    # Maximum number of traces to sample for each interval
    SAMPLE_SIZE = 100

    # Time interval for each sample in seconds
    INTERVAL = 5

    #

    def self.start!(config = Config.new)
      new(config).start!
    end

    attr_reader :config, :worker, :samples

    def initialize(config)
      @config = config
      @worker = Worker.new(self)
    end

    def start!
      @worker.start!
      Subscriber.register!
      self
    end

    def trace(endpoint = nil)
      # If there already is a trace going on, then just continue
      if t = Thread.current[Trace::KEY]
        return yield
      end

      # If the request should not be sampled, yield
      unless trace = create_trace(endpoint)
        return yield
      end

      # Otherwise, setup the new trace and continue
      begin
        Thread.current[Trace::KEY] = trace
        yield(trace)
      ensure
        Thread.current[Trace::KEY] = nil

        begin
          trace.commit
          process(trace)
        rescue Exception => e
          p [ :EXCEPTION, e ]
          puts e.backtrace
        end
      end
    end

  private

    def create_trace(endpoint)
      Trace.new(endpoint)
    end

    def process(trace)
      @worker.submit(trace)
    end

  end
end
