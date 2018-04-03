module Skylight
  class Trace < Core::Trace

    def initialize(*)
      super
      @too_many_spans = false
    end

    def too_many_spans!
      @too_many_spans = true
    end

    def too_many_spans?
      !!@too_many_spans
    end

    def maybe_broken(e)
      if e.is_a?(Skylight::MaximumTraceSpansError) && config.get(:report_max_spans_exceeded)
        too_many_spans!
      else
        super
      end
    end

    def traced
      if too_many_spans?
          error("[E%04d] The request exceeded the maximum number of spans allowed. It will still " \
                  "be tracked but with reduced information. endpoint=%s", Skylight::MaximumTraceSpansError.code, endpoint)
      end

      super
    end

    private

      def track_gc(*)
        # This attempts to log another span which will fail if we have too many
        return if too_many_spans?
        super
      end

  end
end
