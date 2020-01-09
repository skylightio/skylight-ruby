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
              Skylight.instrument(title: self.class.name, category: "rack.app") { super }
            end
          end

          class Probe
            def install
              # We don't have access to the config here so we can't check whether source locations are enabled.
              # However, this only happens once per middleware so it should be minimal impact.
              # FIXME:
              source_file, source_line = ::ActionDispatch::Routing::RouteSet.instance_method(:call).source_location
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
