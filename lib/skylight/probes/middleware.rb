module Skylight
  module Probes
    module Middleware
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
          middleware.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
            alias call_without_sk call
            def call(*args, &block)
              return call_without_sk(*args, &block) if Skylight::Probes::Middleware::Probe.disabled?

              traces = Skylight::Fanout.each_trace.to_a
              return call_without_sk(*args, &block) if traces.empty?

              begin
                name = self.class.name || "#{default_name}"

                traces.each{ |t| t.endpoint = name }

                spans = Skylight::Fanout.instrument(title: name, category: "#{category}")
                resp = call_without_sk(*args, &block)

                proxied_response = Skylight::Middleware.with_after_close(resp) do
                  Skylight::Fanout.done(spans)
                end
              rescue Exception => err
                # FIXME: Log this?
                Skylight::Fanout.done(spans, exception_object: err)
                raise
              ensure
                unless err || proxied_response
                  # If we've gotten to this point, the most likely scenario is that
                  # a throw/catch has bypassed a portion of the callstack. Since these spans would not otherwise
                  # be closed, mark them deferred to indicate that they should be implicitly closed.
                  # See Core::Trace#deferred_spans or Core::Trace#stop for more information.
                  Skylight::Fanout.done(spans, defer: true)
                end
              end
            end
          RUBY
        end

        def install
          return if defined?(::ActionDispatch::MiddlewareStack::InstrumentationProxy)

          ::ActionDispatch::MiddlewareStack::Middleware.class_eval do
            alias_method :build_without_sk, :build
            def build(*args)
              sk_instrument_middleware(build_without_sk(*args))
            end

            def sk_instrument_middleware(middleware)
              return middleware if middleware.is_a?(Skylight::Middleware)

              # Not sure how this would actually happen
              return middleware if middleware.respond_to?(:call_without_sk)

              # On Rails 3, ActionDispatch::Session::CookieStore is frozen, for one
              return middleware if middleware.frozen?

              Skylight::Probes::Middleware::Probe.add_instrumentation(middleware)

              middleware
            end
          end
        end
      end
    end

    register(:middleware, "ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch", Middleware::Probe.new)
  end
end
