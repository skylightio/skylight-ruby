module Skylight
  module Probes
    module Moped
      class Probe

        def install
          unless defined?(::Moped::Instrumentable)
            # Using $stderr here isn't great, but we don't have a logger accessible
            $stderr.puts "[SKYLIGHT] [#{Skylight::VERSION}] The installed version of Moped doesn't " \
                          "support instrumentation. The Moped probe will be disabled."

            return
          end

          ::Moped::Instrumentable.module_eval do
            alias instrument_without_sk instrument

            def instrument(*args, &block)
              # Mongoid sets the instrumenter to AS::N
              if instrumenter == ActiveSupport::Notifications
                asn_block = block
              else
                # If the instrumenter hasn't been changed to AS::N use both
                asn_block = Proc.new do
                  ActiveSupport::Notifications.instrument(*args, &block)
                end
              end

              instrument_without_sk(*args, &asn_block)
            end
          end
        end

      end
    end

    register("Moped", "moped", Moped::Probe.new)
  end
end