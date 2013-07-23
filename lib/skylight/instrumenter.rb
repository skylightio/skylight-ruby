require 'thread'

module Skylight
  class Instrumenter
    KEY  = :__skylight_current_trace
    LOCK = Mutex.new

    include Util::Logging

    def self.current_trace
      Thread.current[KEY]
    end

    def self.current_trace=(trace)
      Thread.current[KEY] = trace
    end

    def self.instance
      @instance
    end

    def self.start!(config = Config.new)
      return @instance if @instance

      LOCK.synchronize do
        return @instance if @instance
        @instance = new(config).start!
      end
    end

    def self.stop!
      LOCK.synchronize do
        return unless @instance
        @instance.shutdown
        @instance = nil
      end
    end

    attr_reader :config, :gc

    def initialize(config)
      if Hash === config
        config = Config.new(config)
      end

      @gc = config.gc
      @config = config
      @worker = config.worker.build
      @subscriber = Subscriber.new(config)
    end

    def start!
      return unless config

      t { "starting instrumenter" }
      @config.validate!
      @config.gc.enable
      @worker.spawn
      @subscriber.register!

      self

    rescue Exception => e
      error "failed to start instrumenter; msg=%s", e.message
      nil
    end

    def shutdown
      @subscriber.unregister!
      @worker.shutdown
    end

    def trace(endpoint, cat, *args)
      # If a trace is already in progress, continue with that one
      if trace = Instrumenter.current_trace
        t { "already tracing" }
        return yield(trace) if block_given?
        return trace
      end

      begin
        trace = Messages::Trace::Builder.new(self, endpoint, Util::Clock.micros, cat, *args)
      rescue Exception => e
        error e.message
        t { e.backtrace.join("\n") }
        return
      end

      Instrumenter.current_trace = trace
      return trace unless block_given?

      begin
        yield trace

      ensure
        Instrumenter.current_trace = nil
        trace.submit
      end
    end

    def instrument(cat, *args)
      unless trace = Instrumenter.current_trace
        return yield if block_given?
        return
      end

      cat = cat.to_s

      unless cat =~ CATEGORY_REGEX
        warn "invalid skylight instrumentation category; value=%s", cat
        return yield if block_given?
        return
      end

      cat = "other.#{cat}" unless cat =~ TIER_REGEX

      unless sp = trace.instrument(cat, *args)
        return yield if block_given?
        return
      end

      return sp unless block_given?

      begin
        yield sp
      ensure
        sp.done
      end
    end

    def process(trace)
      t { fmt "processing trace; spans=%d; duration=%d",
            trace.spans.length, trace.spans[-1].duration }
      unless @worker.submit(trace)
        warn "failed to submit trace to worker"
      end
    end

  end
end
