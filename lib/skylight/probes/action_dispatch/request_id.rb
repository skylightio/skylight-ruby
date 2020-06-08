module Skylight
  module Probes
    module ActionDispatch
      module RequestId
        module Instrumentation
          def call(env)
            @skylight_request_id = env["skylight.request_id"]
            super
          end

          private

            def internal_request_id
              @skylight_request_id || super
            end
        end

        class Probe
          def install
            ::ActionDispatch::RequestId.prepend(Instrumentation)
          end
        end
      end
    end

    register(:action_dispatch, "ActionDispatch::RequestId", "action_dispatch/middleware/request_id",
             ActionDispatch::RequestId::Probe.new)
  end
end
