# frozen_string_literal: true

module Skylight
  module Probes
    module ActionDispatch
      module ShowExceptions
        module Instrumentation
          def initialize(...)
            super

            exceptions_app = @exceptions_app
            @exceptions_app =
              lambda do |env|
                Skylight.instrumenter&.current_trace&.segment = "error"
                Skylight.mute(ignore: :endpoint_assignment) { exceptions_app.call(env) }
              end
          end
        end

        class Probe
          def install
            ::ActionDispatch::ShowExceptions.prepend(Instrumentation)
          end
        end
      end
    end

    register(
      :rails_show_exceptions,
      "ActionDispatch::ShowExceptions",
      "action_dispatch/show_exceptions",
      ActionDispatch::ShowExceptions::Probe.new
    )
  end
end
