module Skylight::Core
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
              return middleware if middleware.is_a?(Skylight::Core::Middleware)

              # Not sure how this would actually happen
              return middleware if middleware.respond_to?(:call_without_sk)

              # On Rails 3, ActionDispatch::Session::CookieStore is frozen, for one
              return middleware if middleware.frozen?

              middleware.instance_eval do
                alias call_without_sk call
                def call(*args, &block)
                  traces = Skylight::Core::Fanout.registered.map do |r|
                    r.instrumenter ? r.instrumenter.current_trace : nil
                  end.compact

                  return call_without_sk(*args, &block) if traces.empty?

                  begin
                    name = self.class.name || "Anonymous Middleware"

                    traces.each{|t| t.endpoint = name }

                    spans = Skylight::Core::Fanout.instrument(title: name, category: "rack.middleware")
                    resp = call_without_sk(*args, &block)

                    Skylight::Core::Middleware.with_after_close(resp) do
                      # trace.done(span)
                      Skylight::Core::Fanout.done(spans)
                    end
                  rescue Exception => e
                    # FIXME: Log this?
                    # trace.done(span)
                    Skylight::Core::Fanout.done(spans, exception_object: e)
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
