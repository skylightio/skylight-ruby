module Skylight
  module Probes
    module Middleware
      # for Rails >= 6.0, which includes InstrumentationProxy
      module InstrumentationExtensions
        def initialize(middleware, class_name)
          super

          # NOTE: Caching here leads to better performance, but will not notice if the method is overridden
          # We don't have access to the config here so we can't check whether source locations are enabled.
          # However, this only happens once per middleware so it should be minimal impact.
          @payload[:sk_source_location] =
            begin
              if middleware.is_a?(Proc)
                middleware.source_location
              elsif middleware.respond_to?(:call)
                middleware.method(:call).source_location
              end
            rescue
              nil
            end
        end
      end

      # for Rails <= 5.2 ActionDispatch::MiddlewareStack::Middleware
      module Instrumentation
        def build(*)
          sk_instrument_middleware(super)
        end

        def sk_instrument_middleware(middleware)
          return middleware if middleware.is_a?(Skylight::Middleware)

          # Not sure how this would actually happen
          return middleware if middleware.respond_to?(:__has_sk__)

          # On Rails 3, ActionDispatch::Session::CookieStore is frozen, for one
          return middleware if middleware.frozen?

          Skylight::Probes::Middleware::Probe.add_instrumentation(middleware)

          middleware
        end
      end

      class Probe
        DISABLED_KEY = :__skylight_middleware_disabled

        def self.disable!
          @disabled = true
        end

        def self.enable!
          @disabled = false
        end

        def self.disabled?
          !!@disabled
        end

        module InstanceInstrumentation
          def call(*args)
            return super(*args) if Skylight::Probes::Middleware::Probe.disabled?

            trace = Skylight.instrumenter&.current_trace
            return super(*args) unless trace

            begin
              name = self.class.name || __sk_default_name

              trace.endpoint = name

              source_file, source_line = method(__method__).super_method.source_location

              spans = Skylight.instrument(title: name, category: __sk_category,
                                          source_file: source_file, source_line: source_line)

              proxied_response =
                Skylight::Middleware.with_after_close(super(*args), debug_identifier: "Middleware: #{name}") do
                  Skylight.done(spans)
                end
            rescue Exception => e
              Skylight.done(spans, exception_object: e)
              raise
            ensure
              unless e || proxied_response
                # If we've gotten to this point, the most likely scenario is that
                # a throw/catch has bypassed a portion of the callstack. Since these spans would not otherwise
                # be closed, mark them deferred to indicate that they should be implicitly closed.
                # See Trace#deferred_spans or Trace#stop for more information.
                Skylight.done(spans, defer: true)
              end
            end
          end

          def __sk_default_name
            "Anonymous Middleware"
          end

          def __sk_category
            "rack.middleware"
          end

          def __has_sk__
            true
          end
        end

        def self.add_instrumentation(middleware)
          middleware.singleton_class.prepend(InstanceInstrumentation)
        end

        def install
          if defined?(::ActionDispatch::MiddlewareStack::InstrumentationProxy)
            ::ActionDispatch::MiddlewareStack::InstrumentationProxy.prepend(InstrumentationExtensions)
          else
            ::ActionDispatch::MiddlewareStack::Middleware.prepend(Instrumentation)
          end
        end
      end
    end

    register(:middleware, "ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch",
             Middleware::Probe.new)
  end
end
