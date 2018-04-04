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

    def broken?
      !!@broken
    end

    def maybe_broken(e)
      error "failed to instrument span; msg=%s; endpoint=%s", e.message, endpoint
      broken!
    end

    def record(cat, title=nil, desc=nil)
      return if broken?

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      desc = @instrumenter.limited_description(desc)

      time = Util::Clock.nanos - gc_time

      stop(start(time, cat, title, desc, nil), time)

      nil
    rescue => e
      maybe_broken(e)
      nil
    end

    def instrument(cat, title=nil, desc=nil, meta=nil)
      return if broken?
      t { "instrument: #{cat}, #{title}" }

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      original_desc = desc
      now           = Util::Clock.nanos
      desc          = @instrumenter.limited_description(desc)

      if desc == Instrumenter::TOO_MANY_UNIQUES
        error "[E0002] The number of unique span descriptions allowed per-request has been exceeded " \
                  "for endpoint: #{endpoint}."
        debug "original desc=%s", original_desc
        debug "cat=%s, title=%s, desc=%s", cat, title, desc
      end

      start(now - gc_time, cat, title, desc, meta)
    rescue => e
      maybe_broken(e)
      nil
    end

    def span_correlation_header(span)
      return unless span
      native_span_get_correlation_header(span)
    end

    def done(span, meta=nil)
      # `span` will be `nil` if we failed to start instrumenting, such as in
      # the case of too many spans in a request.
      return unless span

      return if broken?

      if meta && (meta[:exception_object] || meta[:exception])
        native_span_set_exception(span, meta[:exception_object], meta[:exception])
      end

      stop(span, Util::Clock.nanos - gc_time)
    rescue => e
      error "failed to close span; msg=%s; endpoint=%s", e.message, endpoint
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
      gc = gc_time
      now = Util::Clock.nanos
      track_gc(gc, now)
      stop(@root, now)
    end

    def submit
      t { "submitting trace; broken=#{broken?}" }

      return if broken?

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

    def track_gc(time, now)
      if time > 0
        t { fmt "tracking GC time; duration=%d", time }
        stop(start(now - time, GC_CAT, nil, nil, nil), now)
      end
    end

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
        message = "[E0001] Spans were closed out of order. Expected to see '#{native_span_get_title(expected)}', " \
                    "but got '#{native_span_get_title(span)}' instead."

        if native_span_get_category(span) == "rack.middleware" &&
            Probes.installed.keys.include?("ActionDispatch::MiddlewareStack::Middleware")
          if Probes::Middleware::Probe.disabled?
            message << "\nWe disabled the Middleware probe but unfortunately, this didn't solve the issue."
          else
            Probes::Middleware::Probe.disable!
            message << "\n#{native_span_get_title(span)} may be a Middleware that doesn't fully conform " \
                        "to the Rack SPEC. We've disabled the Middleware probe to see if that resolves the issue."
          end
        end

        message << "\nThis request will not be tracked. Please contact support@skylight.io for more information."

        error message

        t { "expected=#{expected}, actual=#{span}" }

        broken!
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
