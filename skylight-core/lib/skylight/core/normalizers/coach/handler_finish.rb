module Skylight::Core
  module Normalizers
    module Coach
      class HandlerFinish < Normalizer
        register "coach.handler.finish"

        CAT = "app.coach.handler".freeze

        # See information on the events Coach emits here:
        # https://github.com/gocardless/coach#instrumentation

        # Run when the handler first starts, we need to set the trace endpoint to be the
        # handler name.
        #
        # We can expect the payload to have the :middleware key.
        def normalize(trace, name, payload)
          trace.endpoint = payload[:middleware]
          [CAT, payload[:middleware], nil]
        end

        def normalize_after(trace, span, name, payload)
          return unless config.enable_segments?

          segments = []

          response_status = payload.fetch(:response, {}).fetch(:status, "").to_s
          segments << "error" if response_status.start_with?("4", "5")

          if segments.any?
            trace.segment = segments.join("+")
          end
        end
      end
    end
  end
end
