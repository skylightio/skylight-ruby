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

      @lock    = Mutex.new
      @config  = config
      @started = false
      @worker  = config.worker.build
      @gc      = config.gc
    end

    def start!
      # Quick check
      return self if @started
      return unless config

      @lock.synchronize do
        # Ensure that the instrumenter has not been started now that the lock
        # has been acquired.
        return self if @started

        @worker.spawn

        @started = true
      end

      self

    rescue Exception => e
      error "failed to start instrumenter; msg=%s", e.message
      nil
    end

    def trace(endpoint = nil)
      # Ignore everything unless the instrumenter has been started
      unless @started
        return yield
      end

      # If a trace is already in progress, continue with that one
      if Instrumenter.current_trace
        return yield
      end

      trace = Trace.new(endpoint, Util::Clock.now)

      begin

        Instrumenter.current_trace = trace
        yield trace

      ensure
        Instrumenter.current_trace = nil

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
      trace "submitting trace to worker"

      unless @worker.submit(trace)
        warn "failed to submit trace to worker"
      end
    end

  end
end
