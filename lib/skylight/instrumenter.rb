require 'thread'
require 'set'
require 'base64'

module Skylight
  class Instrumenter
    KEY  = :__skylight_current_trace
    LOCK = Mutex.new
    DESC_LOCK = Mutex.new

    TOO_MANY_UNIQUES = "<too many unique descriptions>"

    include Util::Logging

    class TraceInfo
      def current
        Thread.current[KEY]
      end

      def current=(trace)
        Thread.current[KEY] = trace
      end
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

    attr_reader :config, :gc, :trace_info

    def initialize(config)
      if Hash === config
        config = Config.new(config)
      end

      @gc = config.gc
      @config = config
      @worker = config.worker.build
      @subscriber = Subscriber.new(config, self)

      @trace_info = @config[:trace_info] || TraceInfo.new
      @descriptions = Hash.new { |h,k| h[k] = Set.new }
    end

    def current_trace
      @trace_info.current
    end

    def current_trace=(trace)
      @trace_info.current = trace
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
      if trace = @trace_info.current
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

      @trace_info.current = trace
      return trace unless block_given?

      begin
        yield trace

      ensure
        @trace_info.current = nil
        trace.submit
      end
    end

    def disable
      @disabled = true
      yield
    ensure
      @disabled = false
    end

    def disabled?
      @disabled
    end

    def instrument(cat, *args)
      unless trace = @trace_info.current
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

    def limited_description(description)
      endpoint = @trace_info.current.endpoint

      DESC_LOCK.synchronize do
        set = @descriptions[endpoint]

        if set.size >= 100
          return TOO_MANY_UNIQUES if set.size >= 100
        end

        set << description
        description
      end
    end

    def error(reason, body)
      t { fmt "processing error; reason=%s; body=%s", reason, body }

      if body.encoding == Encoding::BINARY || !body.valid_encoding?
        body = Base64.encode64(body)
      end

      message = Skylight::Messages::Error.new(reason: reason, body: body)

      unless @worker.submit(message)
        warn "failed to submit error to worker"
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
