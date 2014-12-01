module Skylight
  module Probes
    module Sinatra
      class Probe
        def install
          class << ::Sinatra::Base
            alias build_without_sk build
            alias compile_without_sk! compile!

            def compile!(verb, path, *args, &block)
              compile_without_sk!(verb, path, *args, &block).tap do |_, _, _, wrapper|
                if path.is_a?(Regexp)
                  human_readable = "<sk-regex>%r{#{path.source}}</sk-regex>"
                  wrapper.instance_variable_set(:@route_name, "#{verb} #{human_readable}")
                end
              end
            end

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
                instrumenter = Skylight::Instrumenter.instance
                next unless instrumenter
                trace = instrumenter.current_trace
                next unless trace

                route = env['sinatra.route']
                trace.endpoint = route if route
              end
            end

            def compile_template(engine, data, options, *args, &block)
              case data
              when Symbol
                options[:sky_virtual_path] = data.to_s
              else
                options[:sky_virtual_path] = "Inline template (#{engine})"
              end

              compile_template_without_sk(engine, data, options, *args, &block)
            end
          end
        end
      end
    end

    register("Sinatra::Base", "sinatra/base", Sinatra::Probe.new)
  end
end
