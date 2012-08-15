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
      @config  = config
      @worker  = Worker.new(self)
      @samples = []
      @current = nil
      @mutex   = Mutex.new
    end

    def start!
      @worker = Worker.start
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
          synchronize { trace.commit }
        rescue Exception => e
          p [ :EXCEPTION, e ]
          puts e.backtrace
        end
      end
    end

    def completed_samples(now)
      synchronize do
        @samples.delete_if { }
      end
    end

    # Global synchronization
    def synchronize
      @mutex.synchronize { yield }
    end

  private

    def create_trace(endpoint)
      now = Time.now

      slot = synchronize do
        # Ensure that we are using the correct sample
        if !@current || @current.from + INTERVAL <= now
          # Prevent the worker from being overloaded
          return if @samples.length >= 10

          # We're good, create the trace
          @current = Sample.new interval_for(now), SAMPLE_SIZE
          @samples << @current
        end

        @current.reserve
      end

      Trace.new(slot, endpoint) if slot
    end

    def interval_for(time)
      Time.at INTERVAL * (time / INTERVAL + 1)
    end

  end
end
