require 'thread'

module Skylight
  class Instrumenter
    KEY = :__skylight_current_trace

    include Util::Logging

    def self.current_trace
      Thread.current[KEY]
    end

    def self.current_trace=(trace)
      Thread.current[KEY] = trace
    end

    def self.start!(config = Config.new)
      new(config).start!
    end

    attr_reader :config, :gc

    def initialize(config)
      if Hash === config
        config = Config.new(config)
      end

      @gc = config.gc
      @lock = Mutex.new
      @config = config
      @worker = config.worker.build
      @started = false
      @subscriber = Subscriber.new(config)
    end

    def start!
      # Quick check
      return self if @started
      return unless config

      @lock.synchronize do
        # Ensure that the instrumenter has not been started now that the lock
        # has been acquired.
        return self if @started

        t { "starting instrumenter" }
        @config.validate!
        @config.gc.enable
        @worker.spawn
        @subscriber.register!

        @started = true
      end

      self

    rescue Exception => e
      error "failed to start instrumenter; msg=%s", e.message
      nil
    end

    def shutdown
      @lock.synchronize do
        return unless @started
        @subscriber.unregister!
        @worker.shutdown
      end
    end

    def trace(endpoint = 'Unknown')
      # Ignore everything unless the instrumenter has been started
      unless @started
        return yield
      end

      # If a trace is already in progress, continue with that one
      if trace = Instrumenter.current_trace
        t { "already tracing" }
        return yield(trace)
      end

      trace = Messages::Trace::Builder.new(endpoint, Util::Clock.now, @config)

      begin

        Instrumenter.current_trace = trace
        yield trace

      ensure
        Instrumenter.current_trace = nil

        begin
          built = trace.build

          if built && built.valid?
            process(built)
          else
            debug "trace invalid -- dropping"
          end
        rescue Exception => e
          error e
        end
      end
    end

  private

    def process(trace)
      t { fmt "processing trace; spans=%d", trace.spans.length }
      unless @worker.submit(trace)
        warn "failed to submit trace to worker"
      end
    end

  end
end
