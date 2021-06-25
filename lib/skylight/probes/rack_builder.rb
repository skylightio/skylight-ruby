module Skylight
  module Probes
    module Rack
      module Builder
        module Instrumentation
          def use(middleware, *args, &block)
            if @map
              mapping, @map = @map, nil
              @use << proc { |app| generate_map(app, mapping) }
            end
            @use << proc do |app|
              middleware
                .new(app, *args, &block)
                .tap do |middleware_instance|
                  Skylight::Probes::Middleware::Instrumentation.sk_instrument_middleware(middleware_instance)
                end
            end
          end
          ruby2_keywords(:use) if respond_to?(:ruby2_keywords, true)
        end

        class Probe
          def install
            if defined?(::Rack.release) && Gem::Version.new(::Rack.release) >= ::Gem::Version.new("2.0") &&
                 defined?(::Rack::Builder)
              ::Rack::Builder.prepend(Instrumentation)
            end
          end
        end
      end
    end

    register(:rack_builder, "Rack::Builder", "rack/builder", Skylight::Probes::Rack::Builder::Probe.new)
  end
end
