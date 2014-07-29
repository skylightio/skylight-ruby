module Skylight
  module Probes
    module Excon
      class Probe
        def install
          if defined?(::Excon::Middleware)
            # Don't require until installation since it depends on Excon being loaded
            require 'skylight/probes/excon/middleware'

            idx = ::Excon.defaults[:middlewares].index(::Excon::Middleware::Instrumentor)

            # TODO: Handle possibility of idx being nil
            ::Excon.defaults[:middlewares].insert(idx, Skylight::Probes::Excon::Middleware)
          else
            # Using $stderr here isn't great, but we don't have a logger accessible
            $stderr.puts "[SKYLIGHT] [#{Skylight::VERSION}] The installed version of Excon doesn't " \
                          "support Middlewares. The Excon probe will be disabled."
          end
        end
      end
    end

    register("Excon", "excon", Excon::Probe.new)
  end
end