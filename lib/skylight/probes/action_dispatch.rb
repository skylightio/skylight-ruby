module Skylight
  module Probes
    module ActionDispatch
      module Routing
        module RouteSet
          class Probe

            def install
              ::ActionDispatch::Routing::RouteSet.class_eval do
                alias call_without_sk call
                def call(env)
                  trace = Skylight::Instrumenter.try(:instance).try(:current_trace)
                  return call_without_sk(env) unless trace

                  trace.endpoint = self.class.name
                  Skylight.instrument(title: self.class.name, category: 'rack.app') do
                    call_without_sk(env)
                  end
                end
              end
            end
          end

        end
      end
    end

    register(:rails_router, 'ActionDispatch::Routing::RouteSet', 'action_dispatch/routing/route_set', ActionDispatch::Routing::RouteSet::Probe.new)
  end
end
