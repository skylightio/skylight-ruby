module Skylight
  module Probes
    module Sinatra
      module ClassInstrumentation
        def compile!(verb, path, *)
          super.tap do |_, _, keys_or_wrapper, wrapper|
            wrapper ||= keys_or_wrapper

            # Deal with the situation where the path is a regex, and the default behavior
            # of Ruby stringification produces an unreadable mess
            if path.is_a?(Regexp)
              human_readable = "<sk-regex>%r{#{path.source}}</sk-regex>"
              wrapper.instance_variable_set(:@route_name, "#{verb} #{human_readable}")
            else
              wrapper.instance_variable_set(:@route_name, "#{verb} #{path}")
            end
          end
        end
      end

      module Instrumentation
        def dispatch!(*)
          super.tap do
            if (trace = Skylight.instrumenter&.current_trace) && (route = env["sinatra.route"])
              # Include the app's mount point (if available)
              script_name = trace.instrumenter.config.sinatra_route_prefixes? && env["SCRIPT_NAME"]

              trace.endpoint =
                if script_name && !script_name.empty?
                  verb, path = route.split(" ", 2)
                  "#{verb} [#{script_name}]#{path}"
                else
                  route
                end
            end
          end
        end

        def compile_template(engine, data, options, *)
          super.tap do |template|
            if defined?(::Tilt::Template) && template.is_a?(::Tilt::Template)
              # Pass along a useful "virtual path" to Tilt. The Tilt probe will handle
              # instrumenting correctly.
              virtual_path = data.is_a?(Symbol) ? data.to_s : "Inline template (#{engine})"
              template.instance_variable_set(:@__sky_virtual_path, virtual_path)
            end
          end
        end
      end

      class Probe
        def install
          if ::Sinatra::VERSION < "1.4.0"
            Skylight.error "Sinatra must be version 1.4.0 or greater."
            return
          end

          ::Sinatra::Base.singleton_class.prepend(ClassInstrumentation)
          ::Sinatra::Base.prepend(Instrumentation)
        end
      end
    end

    register(:sinatra, "Sinatra::Base", "sinatra/base", Sinatra::Probe.new)
  end
end
