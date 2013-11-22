module Skylight
  module Probes
    module Excon
      class Probe
        def install
          # Don't require until installation since it depends on Excon being loaded
          require 'skylight/probes/excon/middleware'

          idx = ::Excon.defaults[:middlewares].index(::Excon::Middleware::Instrumentor)

          # TODO: Handle possibility of idx being nil
          ::Excon.defaults[:middlewares].insert(idx, Skylight::Probes::Excon::Middleware)
        end
      end
    end

    register("Excon", "excon", Excon::Probe.new)
  end
end