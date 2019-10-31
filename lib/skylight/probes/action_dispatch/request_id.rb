module Skylight
  module Probes
    module ActionDispatch
      module RequestId
        class Probe
          def install
            ::ActionDispatch::RequestId.class_eval do
              alias_method :call_without_sk, :call

              def call(env)
                @skylight_request_id = env["skylight.request_id"]
                call_without_sk(env)
              end

              private

                alias_method :internal_request_id_without_sk, :internal_request_id

                def internal_request_id
                  @skylight_request_id || internal_request_id_without_sk
                end
            end
          end
        end
      end
    end

    register(:action_dispatch, "ActionDispatch::RequestId", "action_dispatch/middleware/request_id", ActionDispatch::RequestId::Probe.new)
  end
end
