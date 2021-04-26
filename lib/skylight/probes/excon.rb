module Skylight
  module Probes
    module Excon
      # Probe for instrumenting Excon requests. Installs {Excon::Middleware} to achieve this.
      class Probe
        def install
          if defined?(::Excon::Middleware)
            # Don't require until installation since it depends on Excon being loaded
            require "skylight/probes/excon/middleware"

            idx = ::Excon.defaults[:middlewares].index(::Excon::Middleware::Instrumentor)

            # TODO: Handle possibility of idx being nil
            ::Excon.defaults[:middlewares].insert(idx, Probes::Excon::Middleware)
          else
            Skylight.error "The installed version of Excon doesn't support Middlewares. " \
                             "The Excon probe will be disabled."
          end
        end
      end
    end

    register(:excon, "Excon", "excon", Excon::Probe.new)
  end
end
