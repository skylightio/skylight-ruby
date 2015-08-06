module Skylight
  module Normalizers
    module ActionController
      class ProcessAction < Normalizer
        register "process_action.action_controller"

        CAT = "app.controller.request".freeze
        PAYLOAD_KEYS = %w[ controller action params format method path ].map(&:to_sym).freeze

        def normalize(trace, name, payload)
          trace.endpoint = controller_action(payload)
          [ CAT, trace.endpoint, nil ]
        end

      private

        def controller_action(payload)
          "#{payload[:controller]}##{payload[:action]}"
        end
      end
    end
  end
end
