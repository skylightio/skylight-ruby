module Skylight::Core
  module Normalizers
    module ActionController
      # Normalizer for processing a Rails controller action
      class ProcessAction < Normalizer
        register "process_action.action_controller"

        CAT = "app.controller.request".freeze

        # Payload Keys: controller, action, params, format, method, path
        #   Additional keys available in `normalize_after`: status, view_runtime
        #     Along with ones added by probe: variant

        # @param trace [Skylight::Messages::Trace::Builder]
        # @param name [String] ignored, only present to match API
        # @param payload [Hash]
        # @option payload [String] :controller Controller name
        # @option payload [String] :action Action name
        # @return [Array]
        def normalize(trace, _name, payload)
          trace.endpoint = controller_action(payload)
          [CAT, trace.endpoint, nil]
        end

        def normalize_after(trace, _span, _name, payload)
          return unless config.enable_segments?

          if (segment = segment_from_payload(payload))
            trace.segment = segment
          end
        end

        private

          def controller_action(payload)
            "#{payload[:controller]}##{payload[:action]}"
          end

          def segment_from_payload(payload)
            # Show 'error' if there's an unhandled exception or if the status is 4xx or 5xx
            return "error" if payload[:exception] || payload[:exception_object]
            segment_from_status(payload[:status]) || if payload[:sk_rendered_format]
              # We only show the variant if we actually have a format
              # We won't have a sk_rendered_format if it's a `head` outside of a `respond_to` block.
              [payload[:sk_rendered_format], payload[:sk_variant]].compact.flatten.join("+")
            end
          end

          def segment_from_status(status)
            case status
            when 304
              "not modified"
            when (300..399)
              "redirect"
            when (400..599)
              "error"
            end
          end
      end
    end
  end
end
