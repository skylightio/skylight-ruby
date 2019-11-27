module Skylight
  module Probes
    module Sinatra
      class Probe
        def install
          if ::Sinatra::VERSION < "1.4.0"
            Skylight.error "Sinatra must be version 1.4.0 or greater."
            return
          end

          class << ::Sinatra::Base
            alias_method :compile_without_sk!, :compile!

            def compile!(verb, path, *args, **keywords, &block)
              compile_without_sk!(verb, path, *args, **keywords, &block).tap do |_, _, keys_or_wrapper, wrapper|
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

          ::Sinatra::Base.class_eval do
            alias_method :dispatch_without_sk!, :dispatch!
            alias_method :compile_template_without_sk, :compile_template

            def dispatch!(*args, &block)
              dispatch_without_sk!(*args, &block).tap do
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

            def compile_template(engine, data, options, *args, &block)
              # Pass along a useful "virtual path" to Tilt. The Tilt probe will handle
              # instrumenting correctly.
              options[:sky_virtual_path] = data.is_a?(Symbol) ? data.to_s : "Inline template (#{engine})"

              compile_template_without_sk(engine, data, options, *args, &block)
            end
          end
        end
      end
    end

    register(:sinatra, "Sinatra::Base", "sinatra/base", Sinatra::Probe.new)
  end
end
