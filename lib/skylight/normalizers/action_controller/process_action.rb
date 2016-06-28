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
          return unless config.enable_segments?

          # Show 'error' if there's an unhandled exception or if the status is 4xx or 5xx
          if payload[:exception] || payload[:status].to_s =~ /^[45]/
            segment = "error"
          # We won't have a rendered_format if it's a `head` outside of a `respond_to` block.
          elsif payload[:rendered_format]
            # We only show the variant if we actually have a format
            segment = [payload[:rendered_format], payload[:variant]].compact.flatten.join('+')
          end

          if segment
            trace.endpoint += "<sk-segment>#{segment}</sk-segment>"
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
