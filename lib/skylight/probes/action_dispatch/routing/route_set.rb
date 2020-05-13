module Skylight
  module Probes
    module ActionDispatch
      module Routing
        module RouteSet
          class Probe
            def install
              # We don't have access to the config here so we can't check whether source locations are enabled.
              # However, this only happens once per middleware so it should be minimal impact.
              source_file, source_line = ::ActionDispatch::Routing::RouteSet.instance_method(:call).source_location

              ::ActionDispatch::Routing::RouteSet.class_eval <<-RUBY, __FILE__, __LINE__ + 1
                alias_method :call_without_sk, :call

                def call(env)
                  if (trace = Skylight.instrumenter&.current_trace)
                    trace.endpoint = self.class.name
                  end

                  # Specify source location to avoid pointing back to a calling middleware
                  Skylight.instrument(title: self.class.name, category: "rack.app",
                                      source_file: "#{source_file}", source_line: "#{source_line}") do
                    call_without_sk(env)
                  end
                end
              RUBY
            end
          end
        end
      end
    end

    register(:rails_router, "ActionDispatch::Routing::RouteSet", "action_dispatch/routing/route_set",
             ActionDispatch::Routing::RouteSet::Probe.new)
  end
end
