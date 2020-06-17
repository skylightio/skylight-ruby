module Skylight
  module Probes
    module ActionDispatch
      module Routing
        module RouteSet
          module Instrumentation
            def call(env)
              if (trace = Skylight.instrumenter&.current_trace)
                trace.endpoint = self.class.name
              end

              # FIXME: source_locations
              if Skylight.config&.enable_source_locations?
                source_file, source_line = method(__method__).super_method.source_location
              end

              Skylight.instrument(
                title: self.class.name,
                category: "rack.app",
                source_file: source_file&.to_s,
                source_line: source_line&.to_s
              ) do
                super
              end
            end
          end

          class Probe
            def install
              ::ActionDispatch::Routing::RouteSet.prepend(Instrumentation)
            end
          end
        end
      end
    end

    register(:rails_router, "ActionDispatch::Routing::RouteSet", "action_dispatch/routing/route_set",
             ActionDispatch::Routing::RouteSet::Probe.new)
  end
end
