module Skylight
  module Probes
    module Middleware
      class Probe
        def install
          ActionDispatch::MiddlewareStack::Middleware.class_eval do
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

              middleware.instance_eval do
                alias call_without_sk call
                def call(*args, &block)
                  trace = Skylight::Instrumenter.try(:instance).try(:current_trace)
                  return call_without_sk(*args, &block) unless trace

                  begin
                    trace.endpoint = self.class.name

                    span = Skylight.instrument(title: self.class.name, category: "rack.middleware")
                    resp = call_without_sk(*args, &block)

                    Skylight::Middleware.with_after_close(resp) { trace.done(span) }
                  rescue Exception
                    # FIXME: Log this?
                    trace.done(span)
                    raise
                  end
                end
              end

              middleware
            end
          end
        end
      end
    end

    register("ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch", Middleware::Probe.new)
  end
end
