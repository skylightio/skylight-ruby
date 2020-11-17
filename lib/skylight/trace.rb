require "securerandom"
require "skylight/util/logging"

module Skylight
  class Trace
    GC_CAT = "noise.gc".freeze
    SYNTHETIC = "<synthetic>".freeze

    META_KEYS = %i[mute_children database].freeze

    include Util::Logging

    attr_reader :instrumenter, :endpoint, :segment, :notifications, :meta, :component

    def self.new(instrumenter, endpoint, start, cat, title = nil, desc = nil, meta: nil, segment: nil, component: nil)
      uuid = SecureRandom.uuid
      inst = native_new(normalize_time(start), uuid, endpoint, meta)
      inst.uuid = uuid
      inst.send(:initialize, instrumenter, cat, title, desc, meta, component: component)
      inst.endpoint = endpoint
      inst.segment = segment
      inst
    end

    # TODO: Move this into native
    def self.normalize_time(time)
      # At least one customer has extensions that cause integer division to produce rationals.
      # Since the native code expects an integer, we force it again.
      (time.to_i / 100_000).to_i
    end

    def initialize(instrumenter, cat, title, desc, meta, component: nil)
      raise ArgumentError, "instrumenter is required" unless instrumenter

      @instrumenter = instrumenter
      @submitted = false
      @broken = false

      @notifications = []

      @spans = []

      preprocess_meta(meta) if meta

      # create the root node
      @root = start(native_get_started_at, cat, title, desc, meta, normalize: false)

      # Also store meta for later access
      @meta = meta

      @gc = config.gc.track unless ENV.key?("SKYLIGHT_DISABLE_GC_TRACKING")

      self.component = component if component
      @too_many_spans = false
      native_use_pruning if use_pruning?
    end

    def uuid
      native_get_uuid
    end

    def uuid=(value)
      # We can't change the UUID so just check to make sure we weren't trying to change
      raise "unable to change uuid" unless value == uuid
    end

    def too_many_spans!
      @too_many_spans = true
    end

    def too_many_spans?
      !!@too_many_spans
    end

    def log_context
      @log_context ||= { trace: uuid }
    end

    def endpoint=(value)
      if muted?
        maybe_warn(:endpoint_set_muted, "tried to set endpoint name while muted")
        return
      end
      @endpoint = value
      native_set_endpoint(value)
    end

    def segment=(value)
      if muted?
        maybe_warn(:segment_set_muted, "tried to set segment name while muted")
        return
      end
      @segment = value
    end

    attr_accessor :compound_response_error_status

    def config
      @instrumenter.config
    end

    def muted?
      !!@child_instrumentation_muted_by || @instrumenter.muted?
    end

    def broken?
      !!@broken
    end

    def maybe_broken(err)
      if err.is_a?(Skylight::MaximumTraceSpansError) && config.get(:report_max_spans_exceeded)
        too_many_spans!
      else
        error "failed to instrument span; msg=%s; endpoint=%s", err.message, endpoint
        broken!
      end
    end

    def instrument(cat, title = nil, desc = nil, meta = nil)
      return if muted?
      return if broken?

      t { "instrument: #{cat}, #{title}" }

      title.freeze if title.is_a?(String)
      desc.freeze  if desc.is_a?(String)

      now = Skylight::Util::Clock.nanos

      preprocess_meta(meta) if meta

      start(now - gc_time, cat, title, desc, meta)
    rescue => e
      maybe_broken(e)
      nil
    end

    def done(span, meta = nil)
      # `span` will be `nil` if we failed to start instrumenting, such as in
      # the case of too many spans in a request.
      return unless span
      return if broken?

      if meta&.[](:defer)
        deferred_spans[span] ||= (Skylight::Util::Clock.nanos - gc_time)
        return
      end

      if meta && (meta[:exception_object] || meta[:exception])
        native_span_set_exception(span, meta[:exception_object], meta[:exception])
      end

      stop(span, Skylight::Util::Clock.nanos - gc_time)
    rescue => e
      error "failed to close span; msg=%s; endpoint=%s", e.message, endpoint
      log_trace "Original Backtrace:\n#{e.backtrace.join("\n")}"
      broken!
      nil
    end

    def inspect
      to_s
    end

    def release
      t { "release; is_current=#{@instrumenter.current_trace == self}" }
      return unless @instrumenter.current_trace == self

      @instrumenter.current_trace = nil
    end

    def broken!
      debug "trace is broken"
      @broken = true
    end

    def traced
      if too_many_spans?
        error("[E%04d] The request exceeded the maximum number of spans allowed. It will still " \
              "be tracked but with reduced information. endpoint=%s", Skylight::MaximumTraceSpansError.code, endpoint)
      end

      gc = gc_time
      now = Skylight::Util::Clock.nanos
      track_gc(gc, now)
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

      def track_gc(time, now)
        # This attempts to log another span which will fail if we have too many
        return if too_many_spans?

        if time > 0
          t { fmt "tracking GC time; duration=%d", time }
          meta = { source_location: SYNTHETIC }
          stop(start(now - time, GC_CAT, nil, nil, meta), now)
        end
      end

      def start(time, cat, title, desc, meta, opts = {})
        time = self.class.normalize_time(time) unless opts[:normalize] == false

        mute_children = meta&.delete(:mute_children)

        sp = native_start_span(time, cat.to_s)
        native_span_set_title(sp, title.to_s) if title
        native_span_set_description(sp, desc.to_s) if desc
        native_span_set_meta(sp, meta) if meta
        native_span_started(sp)

        @spans << sp
        t { "started span: #{sp} - #{cat}, #{title}" }

        if mute_children
          t { "muting child instrumentation for span=#{sp}" }
          mute_child_instrumentation(sp)
        end

        sp
      end

      def mute_child_instrumentation(span)
        @child_instrumentation_muted_by = span
      end

      # Middleware spans that were interrupted by a throw/catch should be cached here.
      # keys: span ids
      # values: nsec timestamp at which the span was cached here.
      def deferred_spans
        @deferred_spans ||= {}
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

        if @child_instrumentation_muted_by == span
          @child_instrumentation_muted_by = nil # restart instrumenting
        end
      end

      # Originally extracted from `stop`.
      # If we attempt to close spans out of order, and it appears to be a middleware issue,
      # disable the middleware probe and mark trace as broken.
      def handle_unexpected_stop(expected, span)
        message = "[E0001] Spans were closed out of order. Expected to see '#{native_span_get_title(expected)}', " \
                    "but got '#{native_span_get_title(span)}' instead."

        if native_span_get_category(span) == "rack.middleware" && Skylight::Probes.installed.key?(:middleware)
          if Skylight::Probes::Middleware::Probe.disabled?
            message << "\nWe disabled the Middleware probe but unfortunately, this didn't solve the issue."
          else
            Skylight::Probes::Middleware::Probe.disable!
            message << "\n#{native_span_get_title(span)} may be a Middleware that doesn't fully conform " \
                        "to the Rack SPEC. We've disabled the Middleware probe to see if that resolves the issue."
          end
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

      def use_pruning?
        config.get(:prune_large_traces)
      end

      def resolve_component(component)
        config.components[component].to_encoded_s
      end

      def component=(component)
        resolve_component(component).tap do |c|
          # Would it be better for the component getter to get from native?
          @component = c
          native_set_component(c)
        end
      end

      def preprocess_meta(meta)
        validate_meta(meta)
        instrumenter.extensions.trace_preprocess_meta(meta)
      end

      def validate_meta(meta)
        unknown_keys = meta.keys - allowed_meta_keys
        if unknown_keys.any?
          unknown_keys.each do |key|
            maybe_warn("unknown_meta:#{key}", "Unknown meta key will be ignored; key=#{key.inspect}")
            meta.delete(key)
          end
        end
      end

      def allowed_meta_keys
        META_KEYS | instrumenter.extensions.allowed_meta_keys
      end

      def maybe_warn(context, msg)
        return if warnings_silenced?(context)

        instrumenter.silence_warnings(context)

        warn(msg)
      end

      def warnings_silenced?(context)
        instrumenter.warnings_silenced?(context)
      end
  end
end
