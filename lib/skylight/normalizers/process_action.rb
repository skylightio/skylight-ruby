module Skylight
  module Normalizers
    class ProcessAction < Normalizer
      register "process_action.action_controller"

      def normalize(trace, name, payload)
        trace.endpoint = controller_action(payload)
        [ "app.controller.request", trace.endpoint, nil, payload ]
      end

    private

      def controller_action(payload)
        "#{payload[:controller]}##{payload[:action]}"
      end
    end
  end
end

