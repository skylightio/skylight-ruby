module Skylight
  module Probes
    module Sinatra
      class Probe
        def install
          class << ::Sinatra::Base
            alias build_without_sk build

            def build(*args, &block)
              self.use Skylight::Middleware
              build_without_sk(*args, &block)
            end
          end

          ::Sinatra::Base.class_eval do
            alias dispatch_without_sk! dispatch!
            alias compile_template_without_sk compile_template

            def dispatch!(*args, &block)
              dispatch_without_sk!(*args, &block).tap do
                route = env['sinatra.route']
                Skylight::Instrumenter.instance.current_trace.endpoint = route if route
              end
            end

            def compile_template(engine, data, options, *args, &block)
              case data
              when Symbol
                options[:sky_virtual_path] = data.to_s
              else
                options[:sky_virtual_path] = "Inline template"
              end

              compile_template_without_sk(engine, data, options, *args, &block)
            end
          end
        end
      end
    end

    register("Sinatra", "sinatra", Sinatra::Probe.new)
  end
end
