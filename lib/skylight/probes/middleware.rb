module Skylight
  module Probes
    module Middleware
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

        def self.add_instrumentation(middleware, default_name: "Anonymous Middleware", category: "rack.middleware")
          mod =
            Module.new do
              def __has_sk__
                true
              end

              define_method :call do |*args|
                return super(*args) if Skylight::Probes::Middleware::Probe.disabled?

                trace = Skylight.instrumenter&.current_trace
                return super(*args) unless trace

                begin
                  name = self.class.name || default_name

                  trace.endpoint = name

                  spans = Skylight.instrument(title: name, category: category)

                  proxied_response =
                    Skylight::Middleware.with_after_close(super(*args), debug_identifier: "Middleware: #{name}") do
                      Skylight.done(spans)
                    end
                rescue Exception => e
                  # FIXME: Log this?
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
            end

          middleware.singleton_class.prepend(mod)
        end

        def install
          return if defined?(::ActionDispatch::MiddlewareStack::InstrumentationProxy)

          ::ActionDispatch::MiddlewareStack::Middleware.prepend(Instrumentation)
        end
      end
    end

    register(:middleware, "ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch",
             Middleware::Probe.new)
  end
end
