module Skylight
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
                  type_str = content_type.to_s.split(';').first
                  Mime::Type.lookup(type_str) unless type_str.blank?
                end
              end
              payload[:rendered_format] = rendered_mime.try(:ref)
              payload[:variant] = request.respond_to?(:variant) ? request.variant : nil
            end
          end

          if Gem::Version.new(Rails.version) < Gem::Version.new('4.2.1')
            # Backport https://github.com/rails/rails/pull/17978
            ::ActionController::Instrumentation.class_eval do
              def process_action(*args)
                raw_payload = {
                  :controller => self.class.name,
                  :action     => self.action_name,
                  :params     => request.filtered_parameters,
                  :format     => request.format.try(:ref),
                  :method     => request.request_method,
                  :path       => (request.fullpath rescue "unknown")
                }

                ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

                ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
                  begin
                    result = super
                    payload[:status] = response.status
                    result
                  ensure
                    append_info_to_payload(payload)
                  end
                end
              end
            end
          end
        end
      end
    end

    register("ActionController::Instrumentation", "action_controller/metal/instrumentation", ActionController::Probe.new)
  end
end
