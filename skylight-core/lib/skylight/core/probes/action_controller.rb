module Skylight::Core
  module Probes
    module ActionController
      class Probe
        def install
          ::ActionController::Instrumentation.class_eval do
            private

              alias append_info_to_payload_without_sk append_info_to_payload
              def append_info_to_payload(payload)
                append_info_to_payload_without_sk(payload)
                rendered_mime = begin
                  if respond_to?(:rendered_format)
                    rendered_format
                  elsif content_type.is_a?(Mime::Type)
                    content_type
                  elsif content_type.respond_to?(:to_s)
                    type_str = content_type.to_s.split(";").first
                    Mime::Type.lookup(type_str) unless type_str.blank?
                  end
                end
                payload[:rendered_format] = rendered_mime.try(:ref)
                payload[:variant] = request.respond_to?(:variant) ? request.variant : nil
              end
          end
        end
      end
    end

    register(:action_controller, "ActionController::Instrumentation", "action_controller/metal/instrumentation", ActionController::Probe.new)
  end
end
