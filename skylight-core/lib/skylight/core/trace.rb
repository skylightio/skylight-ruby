module Skylight::Core
  class Trace
    GC_CAT = 'noise.gc'.freeze

    include Util::Logging

    attr_reader :instrumenter, :endpoint, :notifications, :meta

    def self.new(instrumenter, endpoint, start, cat, title=nil, desc=nil, meta=nil)
      inst = native_new(normalize_time(start), "TODO", endpoint, meta)
      inst.send(:initialize, instrumenter, cat, title, desc, meta)
      inst.endpoint = endpoint
      inst
    end

    # TODO: Move this into native
    def self.normalize_time(time)
      # At least one customer has extensions that cause integer division to produce rationals.
      # Since the native code expects an integer, we force it again.
      (time.to_i / 100_000).to_i
    end

    def initialize(instrumenter, cat, title, desc, meta)
      raise ArgumentError, 'instrumenter is required' unless instrumenter

      @instrumenter = instrumenter
      @submitted = false
      @broken = false

      @notifications = []

      @spans = []

      # create the root node
      @root = start(native_get_started_at, cat, title, desc, meta, normalize: false)

      # Also store meta for later access
      @meta = meta

      @gc = config.gc.track unless ENV.key?("SKYLIGHT_DISABLE_GC_TRACKING")
    end

    def endpoint=(value)
      @endpoint = value
      native_set_endpoint(value)
      value
    end

    def config
      @instrumenter.config
    end

    def record(cat, title=nil, desc=nil)
      return if @broken

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      desc = @instrumenter.limited_description(desc)

      time = Util::Clock.nanos - gc_time

      stop(start(time, cat, title, desc, nil), time)

      nil
    rescue => e
      error "failed to record span; msg=%s", e.message
      broken!
      nil
    end

    def instrument(cat, title=nil, desc=nil, meta=nil)
      return if @broken
      t { "instrument: #{cat}, #{title}" }

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      original_desc = desc
      now           = Util::Clock.nanos
      desc          = @instrumenter.limited_description(desc)

      if desc == Instrumenter::TOO_MANY_UNIQUES
        debug "A payload description produced <too many uniques>"
        debug "original desc=%s", original_desc
        debug "cat=%s, title=%s, desc=%s", cat, title, desc
      end

      start(now - gc_time, cat, title, desc, meta)
    rescue => e
      error "failed to instrument span; msg=%s", e.message
      broken!
      nil
    end

    def span_correlation_header(span)
      return unless span
      native_span_get_correlation_header(span)
    end

    def done(span, meta=nil)
      return unless span
      return if @broken

      if meta && (meta[:exception_object] || meta[:exception])
        native_span_set_exception(span, meta[:exception_object], meta[:exception])
      end

      stop(span, Util::Clock.nanos - gc_time)
    rescue => e
      error "failed to close span; msg=%s", e.message
      broken!
      nil
    end

    def release
      return unless @instrumenter.current_trace == self
      @instrumenter.current_trace = nil
    end

    def broken!
      debug "trace is broken"
      @broken = true
    end

    def traced
      time = gc_time
      now = Util::Clock.nanos

      if time > 0
        t { fmt "tracking GC time; duration=%d", time }
        stop(start(now - time, GC_CAT, nil, nil, nil), now)
      end

      stop(@root, now)
    end

    def submit
      t { "submitting trace; broken=#{@broken}" }

      return if @broken

      if @submitted
        t { "already submitted" }
        return
      end

      release
      @submitted = true

      traced

      @instrumenter.process(self)
    rescue Exception => e
      error e.message
      t { e.backtrace.join("\n") }
    end

  private

    def start(time, cat, title, desc, meta, opts={})
      time = self.class.normalize_time(time) unless opts[:normalize] == false

      sp = native_start_span(time, cat.to_s)
      native_span_set_title(sp, title.to_s) if title
      native_span_set_description(sp, desc.to_s) if desc
      native_span_set_meta(sp, meta) if meta
      native_span_started(sp)

      @spans << sp
      t { "started span: #{sp} - #{cat}, #{title}" }

      sp
    end

    def stop(span, time)
      t { "stopping span: #{span}" }

      expected = @spans.pop
      unless span == expected
        error "invalid span nesting"
        # TODO: Actually log span title here
        t { "expected=#{expected}, actual=#{span}" }
      end

      time = self.class.normalize_time(time)
      native_stop_span(span, time)
      nil
    end

    def gc_time
      return 0 unless @gc
      @gc.update
      @gc.time
    end
  end
end
