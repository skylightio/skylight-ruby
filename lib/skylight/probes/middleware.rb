module Skylight
  module Probes
    module Middleware

      def self.add_instrumentation(middleware, default_name="Anonymous Middleware", category="rack.middleware")
        middleware.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
          alias call_without_sk call
          def call(*args, &block)
            trace = Skylight::Instrumenter.try(:instance).try(:current_trace)
            return call_without_sk(*args, &block) unless trace

            begin
              name = self.class.name || "#{default_name}"

              trace.endpoint = name

              span = Skylight.instrument(title: name, category: "#{category}")
              resp = call_without_sk(*args, &block)

              proxied_response = Skylight::Middleware.with_after_close(resp) do
                trace.done(span)
              end
            rescue Exception => err
              # FIXME: Log this?
              trace.done(span, exception_object: err)
              raise
            ensure
              unless err || proxied_response
                # If we've gotten to this point, the most likely scenario is that
                # a throw/catch has bypassed a portion of the callstack. Since these spans would not otherwise
                # be closed, mark them deferred to indicate that they should be implicitly closed.
                # See Core::Trace#deferred_spans or Core::Trace#stop for more information.
                trace.done(span, defer: true)
              end
            end
          end
        RUBY
      end

      class Probe
        def install
          ::ActionDispatch::MiddlewareStack::Middleware.class_eval do
            alias build_without_sk build
            def build(*args)
              sk_instrument_middleware(build_without_sk(*args))
            end

            def sk_instrument_middleware(middleware)
              return middleware if middleware.is_a?(Skylight::Middleware)

              # Not sure how this would actually happen
              return middleware if middleware.respond_to?(:call_without_sk)

              # On Rails 3, ActionDispatch::Session::CookieStore is frozen, for one
              return middleware if middleware.frozen?

              Skylight::Probes::Middleware.add_instrumentation(middleware)

              middleware
            end
          end
        end
      end
    end

    register(:middleware, "ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch", Middleware::Probe.new)
  end
end
