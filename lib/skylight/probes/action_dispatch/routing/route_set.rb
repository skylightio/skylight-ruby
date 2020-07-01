# frozen_string_literal: true

module Skylight
  module Probes
    module ActionDispatch
      module Routing
        module RouteSet
          module Instrumentation
            def call(env)
              ActiveSupport::Notifications.instrument("route_set.action_dispatch") do
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
