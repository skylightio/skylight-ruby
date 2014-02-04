module Skylight
  module Normalizers
    class ProcessAction < Normalizer
      register "process_action.action_controller"

      CAT = "app.controller.request".freeze
      PAYLOAD_KEYS = %w[ controller action params format method path ].map(&:to_sym).freeze

      def normalize(trace, name, payload)
        trace.endpoint = controller_action(payload)
        [ CAT, trace.endpoint, nil, normalize_payload(payload) ]
      end

    private

      def controller_action(payload)
        "#{payload[:controller]}##{payload[:action]}"
      end

      def normalize_payload(payload)
        normalized = {}

        PAYLOAD_KEYS.each do |key|
          normalized[key] = payload[key]
        end

        normalized
      end
    end
  end
end

