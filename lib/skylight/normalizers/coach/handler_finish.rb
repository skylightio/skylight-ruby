module Skylight
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
          [ CAT, payload[:middleware], nil ]
        end

        def normalize_after(trace, span, name, payload)
          return unless config.enable_segments?

          segments = []

          response_status = payload.fetch(:response, {}).fetch(:status, '').to_s
          segments << "error" if response_status.start_with?('4', '5')

          segments.concat(extract_skylight_segments(payload))

          if segments.any?
            trace.endpoint += "<sk-segment>#{segments.join("+")}</sk-segment>"
          end
        end

        private

          # Coach provides a metadata logging facility which can be used to tag requests
          # during execution. It's particularly useful for users to apply segments to the
          # current Skylight trace by logging metadata with keys that have a
          # skylight_segment_ prefix.
          def extract_skylight_segments(payload)
            metadata_keys = payload.fetch(:metadata, {}).keys
            metadata_keys.map do |key|
              match = key.to_s.match(/^skylight_segment_(\S+)/)
              match && match[1]
            end.compact
          end
      end
    end
  end
end
