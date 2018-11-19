require "strscan"
require "securerandom"

module Skylight::Core
  # @api private
  class Instrumenter
    KEY = :__skylight_current_trace

    TOO_MANY_UNIQUES = "<too many unique descriptions>".freeze

    include Util::Logging

    class TraceInfo
      def initialize(key = KEY)
        @key = key
      end

      def current
        Thread.current[@key]
      end

      def current=(trace)
        Thread.current[@key] = trace
      end
    end

    attr_reader :uuid, :config, :gc, :trace_info

    def self.trace_class
      Trace
    end

    def self.native_new(_uuid, _config_env)
      raise "not implemented"
    end

    def self.new(config)
      config.validate!

      uuid = SecureRandom.uuid
      inst = native_new(uuid, config.to_native_env)
      inst.send(:initialize, uuid, config)
      inst
    end

    def initialize(uuid, config)
      @uuid = uuid
      @gc = config.gc
      @config = config
      @subscriber = Subscriber.new(config, self)

      key = "#{KEY}_#{self.class.trace_class.name}".gsub(/\W/, "_")
      @trace_info = @config[:trace_info] || TraceInfo.new(key)
    end

    def log_context
      @log_context ||= { inst: uuid }
    end

    def native_start
      raise "not implemented"
    end

    def native_stop
      raise "not implemented"
    end

    def native_track_desc(_endpoint, _description)
      raise "not implemented"
    end

    def native_submit_trace(_trace)
      raise "not implemented"
    end

    def current_trace
      @trace_info.current
    end

    def current_trace=(trace)
      t { "setting current_trace=#{trace ? trace.uuid : 'nil'}; thread=#{Thread.current.object_id}" }
      @trace_info.current = trace
    end

    def check_install!
      true
    end

    def start!
      # We do this here since we can't report these issues via Gem install without stopping install entirely.
      check_install!

      t { "starting instrumenter" }

      unless config.validate_with_server
        log_error "invalid config"
        return
      end

      t { "starting native instrumenter" }
      unless native_start
        warn "failed to start instrumenter"
        return
      end

      config.gc.enable
      @subscriber.register!

      ActiveSupport::Notifications.instrument("started_instrumenter.skylight", instrumenter: self)

      self
    rescue Exception => e
      log_error "failed to start instrumenter; msg=%s; config=%s", e.message, config.inspect
      t { e.backtrace.join("\n") }
      nil
    end

    def shutdown
      @subscriber.unregister!
      native_stop
    end

    def trace(endpoint, cat, title = nil, desc = nil, meta = nil, segment: nil)
      # If a trace is already in progress, continue with that one
      if (trace = @trace_info.current)
        return yield(trace) if block_given?
        return trace
      end

      begin
        trace = self.class.trace_class.new(self, endpoint, Util::Clock.nanos, cat, title, desc, meta, segment: segment)
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
        t { "instrumenter submitting trace; trace=#{trace.uuid}" }
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

    def self.match?(string, regex)
      @scanner ||= StringScanner.new("")
      @scanner.string = string
      @scanner.match?(regex)
    end

    def match?(string, regex)
      self.class.match?(string, regex)
    end

    def instrument(cat, title = nil, desc = nil, meta = nil)
      raise ArgumentError, "cat is required" unless cat

      unless (trace = @trace_info.current)
        return yield if block_given?
        return
      end

      cat = cat.to_s

      unless match?(cat, Skylight::CATEGORY_REGEX)
        warn "invalid skylight instrumentation category; trace=%s; value=%s", trace.uuid, cat
        return yield if block_given?
        return
      end

      cat = "other.#{cat}" unless match?(cat, Skylight::TIER_REGEX)

      unless (sp = trace.instrument(cat, title, desc, meta))
        return yield if block_given?
        return
      end

      return sp unless block_given?

      meta = {}
      begin
        yield sp
      rescue Exception => e
        meta = { exception: [e.class.name, e.message], exception_object: e }
        raise e
      ensure
        trace.done(sp, meta)
      end
    end

    def span_correlation_header(span)
      return unless (trace = @trace_info.current)
      trace.span_correlation_header(span)
    end

    def broken!
      return unless (trace = @trace_info.current)
      trace.broken!
    end

    def done(span, meta = nil)
      return unless (trace = @trace_info.current)
      trace.done(span, meta)
    end

    def limited_description(description)
      endpoint = @trace_info.current.endpoint

      if description
        if native_track_desc(endpoint, description)
          description
        else
          TOO_MANY_UNIQUES
        end
      end
    end

    def process(trace)
      t { fmt "processing trace=#{trace.uuid}" }

      if ignore?(trace)
        t { fmt "ignoring trace=#{trace.uuid}" }
        return false
      end

      begin
        finalize_endpoint_segment(trace)
        native_submit_trace(trace)
        true
      rescue => e
        warn "failed to submit trace to worker; trace=%s, err=%s", trace.uuid, e
        t { "BACKTRACE:\n#{e.backtrace.join("\n")}" }
        false
      end
    end

    def ignore?(trace)
      config.ignored_endpoints.include?(trace.endpoint)
    end

    # Return [title, sql]
    def process_sql(sql)
      [nil, sql]
    end

    def finalize_endpoint_segment(trace)
      return unless trace.segment
      trace.endpoint += "<sk-segment>#{trace.segment}</sk-segment>"
    end
  end
end
