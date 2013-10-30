module Skylight
  module Normalizers
    class ProcessAction < Normalizer
      register "process_action.action_controller"

      def normalize(trace, name, payload)
        trace.endpoint = controller_action(payload)
        [ "app.controller.request", trace.endpoint, nil, normalize_payload(payload) ]
      end

    private

      def controller_action(payload)
        "#{payload[:controller]}##{payload[:action]}"
      end

      def normalize_payload(payload)
        normalized = {}

        payload.each do |key, value|
          value = value.inspect unless value.is_a?(String) || value.is_a?(Numeric)
          normalized[key] = value
        end

        normalized
      end
    end
  end
end

