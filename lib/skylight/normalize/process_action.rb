module Skylight
  module Normalize
    class ProcessAction < Normalizer
      register "process_action.action_controller"

      def normalize
        @trace.endpoint = controller_action
        [ "app.controller.request", controller_action, nil, @payload ]
      end

    private
      def controller_action
        "#{@payload[:controller]}##{@payload[:action]}"
      end
    end
  end
end
