module Skylight
  module Probes
    module Moped
      class Probe
        def install
          unless defined?(::Moped::Instrumentable)
            Skylight.error "The installed version of Moped doesn't support instrumentation. " \
                           "The Moped probe will be disabled."

            return
          end

          ::Moped::Instrumentable.module_eval do
            alias_method :instrument_without_sk, :instrument

            def instrument(*args, &block)
              # Mongoid sets the instrumenter to AS::N
              asn_block =
                if instrumenter == ActiveSupport::Notifications
                  block
                else
                  # If the instrumenter hasn't been changed to AS::N use both
                  proc do
                    ActiveSupport::Notifications.instrument(*args, &block)
                  end
                end

              instrument_without_sk(*args, &asn_block)
            end
          end
        end
      end
    end

    register(:moped, "Moped", "moped", Moped::Probe.new)
  end
end
