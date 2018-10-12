module Skylight
  class Trace
    GC_CAT = 'noise.gc'.freeze

    include Util::Logging

    attr_reader :endpoint, :notifications

    def self.new(instrumenter, endpoint, start, cat, title = nil, desc = nil)
      inst = native_new(normalize_time(start), "TODO", endpoint)
      inst.send(:initialize, instrumenter, cat, title, desc)
      inst.endpoint = endpoint
      inst
    end

    # TODO: Move this into native
    def self.normalize_time(time)
      # At least one customer has extensions that cause integer division to produce rationals.
      # Since the native code expects an integer, we force it again.
      (time.to_i / 100_000).to_i
    end

    def initialize(instrumenter, cat, title, desc)
      raise ArgumentError, 'instrumenter is required' unless instrumenter

      @instrumenter = instrumenter
      @submitted = false
      @broken = false

      @notifications = []

      @spans = []

      # create the root node
      @root = start(native_get_started_at, cat, title, desc, normalize: false)

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

    def broken?
      !!@broken
    end

    def record(cat, title=nil, desc=nil)
      return if broken?

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      desc = @instrumenter.limited_description(desc)

      time = Util::Clock.nanos - gc_time

      stop(start(time, cat, title, desc), time)

      nil
    rescue => e
      error "failed to record span; msg=%s; endpoint=%s", e.message, endpoint
      broken!
      nil
    end

    def instrument(cat, title=nil, desc=nil)
      return if broken?
      t { "instrument: #{cat}, #{title}" }

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      original_desc = desc
      now           = Util::Clock.nanos
      desc          = @instrumenter.limited_description(desc)

      if desc == Instrumenter::TOO_MANY_UNIQUES
        error "[SKYLIGHT] [#{Skylight::VERSION}] [E0002] You've exceeded the number of unique span descriptions per-request " \
                  "for endpoint: #{endpoint}."
        debug "original desc=%s", original_desc
        debug "cat=%s, title=%s, desc=%s", cat, title, desc
      end

      start(now - gc_time, cat, title, desc)
    rescue => e
      error "failed to instrument span; msg=%s; endpoint=%s", e.message, endpoint
      broken!
      nil
    end

    def done(span, meta=nil)
      return unless span
      return if broken?

      if meta && meta[:defer]
        deferred_spans[span] ||= (Util::Clock.nanos - gc_time)
        return
      end

      stop(span, Util::Clock.nanos - gc_time)
    rescue => e
      error "failed to close span; msg=%s; endpoint=%s", e.message, endpoint
      broken!
      nil
    end

    # Middleware spans that were interrupted by a throw/catch should be cached here.
    # keys: span ids
    # values: nsec timestamp at which the span was cached here.
    def deferred_spans
      @deferred_spans ||= {}
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
        stop(start(now - time, GC_CAT, nil, nil), now)
      end

      stop(@root, now)
    end

    def submit
      t { "submitting trace" }

      # This must always be called to clean up properly
      release

      if broken?
        t { "broken, not submitting" }
        return
      end

      if @submitted
        t { "already submitted" }
        return
      end

      @submitted = true

      traced

      @instrumenter.process(self)
    rescue Exception => e
      error e.message
      t { e.backtrace.join("\n") }
    end

  private

    def start(time, cat, title, desc, opts={})
      time = self.class.normalize_time(time) unless opts[:normalize] == false

      sp = native_start_span(time, cat.to_s)
      native_span_set_title(sp, title.to_s) if title
      native_span_set_description(sp, desc.to_s) if desc

      @spans << sp
      t { "started span: #{sp} - #{cat}, #{title}" }

      sp
    end

    def stop(span, time)
      t { "stopping span: #{span}" }

      # If `stop` is called for a span that is not the last item in the stack,
      # check to see if the last item has been marked as deferred. If so, close
      # that span first, then try to close the original.
      while deferred_spans[expected = @spans.pop]
        normalized_stop(expected, deferred_spans.delete(expected))
      end

      handle_unexpected_stop(expected, span) unless span == expected

      normalized_stop(span, time)
      nil
    end

    def normalized_stop(span, time)
      time = self.class.normalize_time(time)
      native_stop_span(span, time)
    end

    def handle_unexpected_stop(expected, span)
      message = "[E0001] Spans were closed out of order.\n"

      if Skylight::Util::Logging.trace?
        message << "Expected #{expected}, but received #{span}. See prior logs to match id to a name.\n" \
                   "If the received span was a Middleware it may be one that doesn't fully conform to " \
                   "the Rack SPEC."
      else
        message << "To debug this issue set `SKYLIGHT_ENABLE_TRACE_LOGS=true` " \
                   "in your environment. (Beware, it is quite noisy!)\n"
      end

      message << "\nThis request will not be tracked. Please contact support@skylight.io for more information."

      error message

      t { "expected=#{expected}, actual=#{span}" }

      broken!
    end

    def gc_time
      return 0 unless @gc
      @gc.update
      @gc.time
    end
  end
end
