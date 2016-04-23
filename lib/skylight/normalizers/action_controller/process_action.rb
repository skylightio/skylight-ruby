module Skylight
  module Normalizers
    module ActionController
      class ProcessAction < Normalizer
        register "process_action.action_controller"

        CAT = "app.controller.request".freeze

        # Payload Keys: controller, action, params, format, method, path
        #   Additional keys available in `normalize_after`: status, view_runtime
        #     Along with ones added by probe: variant

        def normalize(trace, name, payload)
          trace.endpoint = controller_action(payload)
          [ CAT, trace.endpoint, nil ]
        end

        def normalize_after(trace, span, name, payload)
          return unless config.separate_formats?

          # There are two known cases where we won't have a rendered format
          # 1. Exceptions (in some Rails versions)
          # 2. A `head` response out side of a `respond_to`.

          if !payload[:status]
            # This should mean it's an exception
            format = 'exception'
          else
            format = [payload[:rendered_format], payload[:variant]].compact.flatten.join('+')
          end

          unless format.empty?
            trace.endpoint += "<sk-format>#{format}</sk-format>"
          end
        end

      private

        def controller_action(payload)
          "#{payload[:controller]}##{payload[:action]}"
        end
      end
    end
  end
end
