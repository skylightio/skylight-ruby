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
              payload[:variant] = request.respond_to?(:variant) ? request.variant : nil
            end
          end

          #if RAILS_VERSION < 4.2.1
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
            #end
          end
        end
      end
    end

    register("ActionController::Instrumentation", "action_controller/metal/instrumentation", ActionController::Probe.new)
  end
end
