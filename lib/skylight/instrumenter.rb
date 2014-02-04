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
      @descriptions = Hash.new { |h,k| h[k] = {} }
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
      log_error "failed to start instrumenter; msg=%s", e.message
      nil
    end

    def shutdown
      @subscriber.unregister!
      @worker.shutdown
    end

    def trace(endpoint, cat, title=nil, desc=nil, annot=nil)
      # If a trace is already in progress, continue with that one
      if trace = @trace_info.current
        t { "already tracing" }
        return yield(trace) if block_given?
        return trace
      end

      begin
        trace = Messages::Trace::Builder.new(self, endpoint, Util::Clock.nanos, cat, title, desc, annot)
      rescue Exception => e
        log_error e.message
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

    @scanner = StringScanner.new('')
    def self.match?(string, regex)
      @scanner.string = string
      @scanner.match?(regex)
    end

    def match?(string, regex)
      self.class.match?(string, regex)
    end

    def done(span)
      return unless trace = @trace_info.current
      trace.done(span)
    end

    def instrument(cat, title=nil, desc=nil, annot=nil)
      unless trace = @trace_info.current
        return yield if block_given?
        return
      end

      cat = cat.to_s

      unless match?(cat, CATEGORY_REGEX)
        warn "invalid skylight instrumentation category; value=%s", cat
        return yield if block_given?
        return
      end

      cat = "other.#{cat}" unless match?(cat, TIER_REGEX)

      unless sp = trace.instrument(cat, title, desc, annot)
        return yield if block_given?
        return
      end

      return sp unless block_given?

      begin
        yield sp
      ensure
        trace.done(sp)
      end
    end

    def limited_description(description)
      endpoint = nil
      endpoint = @trace_info.current.endpoint

      DESC_LOCK.synchronize do
        set = @descriptions[endpoint]

        if set.size >= 100
          return TOO_MANY_UNIQUES
        end

        set[description] = true
        description
      end
    end

    def error(type, description, details=nil)
      t { fmt "processing error; type=%s; description=%s", type, description }

      message = Skylight::Messages::Error.build(type, description, details && details.to_json)

      unless @worker.submit(message)
        warn "failed to submit error to worker"
      end
    end

    def process(trace)
      t { fmt "processing trace" }
      unless @worker.submit(trace)
        warn "failed to submit trace to worker"
      end
    end

  end
end
