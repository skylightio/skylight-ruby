module Skylight
  module Normalizers
    module Coach
      class HandlerFinish < Normalizer
        begin
          require "coach/version"
          version = Gem::Version.new(::Coach::VERSION)
        rescue LoadError # rubocop:disable Lint/HandleExceptions
        end

        if version && version < Gem::Version.new("1.0")
          register "coach.handler.finish"
        else
          register "finish_handler.coach"
        end

        CAT = "app.coach.handler".freeze

        # See information on the events Coach emits here:
        # https://github.com/gocardless/coach#instrumentation

        # Run when the handler first starts, we need to set the trace endpoint to be the
        # handler name.
        #
        # We can expect the payload to have the :middleware key.
        def normalize(trace, _name, payload)
          trace.endpoint = payload[:middleware]
          [CAT, payload[:middleware], nil]
        end

        def normalize_after(trace, _span, _name, payload)
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
