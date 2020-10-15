module Skylight
  module Normalizers
    module ActionDispatch
      class RouteSet < Normalizer
        register "route_set.action_dispatch"

        CAT = "rack.app".freeze

        def normalize(trace, _name, _payload)
          trace.endpoint = router_class_name
          [CAT, trace.endpoint, nil]
        end

        private

          def router_class_name
            "ActionDispatch::Routing::RouteSet"
          end

          def process_meta_options(_payload)
            # provide hints to override default source_location behavior
            super.merge(source_location_hint: [:own_instance_method, router_class_name, "call"])
          end
      end
    end
  end
end
