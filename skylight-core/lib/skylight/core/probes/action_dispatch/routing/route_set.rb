module Skylight::Core
  module Probes
    module ActionDispatch
      module Routing
        module RouteSet
          class Probe
            def install
              ::ActionDispatch::Routing::RouteSet.class_eval do
                alias_method :call_without_sk, :call

                def call(env)
                  Skylight::Fanout.endpoint = self.class.name
                  Skylight::Fanout.instrument(title: self.class.name, category: "rack.app") do
                    call_without_sk(env)
                  end
                end
              end
            end
          end
        end
      end
    end

    register(:rails_router, "ActionDispatch::Routing::RouteSet", "action_dispatch/routing/route_set", ActionDispatch::Routing::RouteSet::Probe.new)
  end
end
