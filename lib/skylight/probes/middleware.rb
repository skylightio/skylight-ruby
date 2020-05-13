module Skylight
  module Probes
    module Middleware
      class Probe
        DISABLED_KEY = :__skylight_middleware_disabled

        module InstrumentationExtensions
          def initialize(middleware, class_name)
            super

            # NOTE: Caching here leads to better performance, but will not notice if the method is overridden
            # We don't have access to the config here so we can't check whether source locations are enabled.
            # However, this only happens once per middleware so it should be minimal impact.
            @payload[:source_location] =
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

              trace = Skylight.instrumenter&.current_trace
              return call_without_sk(*args, &block) unless trace

              begin
                name = self.class.name || "#{default_name}"

                trace.endpoint = name

                source_file, source_line = singleton_class.instance_method(:call_without_sk).source_location

                span = Skylight.instrument(title: name, category: "#{category}", source_file: source_file, source_line: source_line)
                resp = call_without_sk(*args, &block)

                proxied_response = Skylight::Middleware.with_after_close(resp, debug_identifier: "Middleware: #{name}") do
                  Skylight.done(span)
                end
              rescue Exception => err
                # FIXME: Log this?
                Skylight.done(span, exception_object: err)
                raise
              ensure
                unless err || proxied_response
                  # If we've gotten to this point, the most likely scenario is that
                  # a throw/catch has bypassed a portion of the callstack. Since these spans would not otherwise
                  # be closed, mark them deferred to indicate that they should be implicitly closed.
                  # See Trace#deferred_spans or Trace#stop for more information.
                  Skylight.done(span, defer: true)
                end
              end
            end
          RUBY
        end

        def install
          if defined?(::ActionDispatch::MiddlewareStack::InstrumentationProxy)
            ::ActionDispatch::MiddlewareStack::InstrumentationProxy.prepend InstrumentationExtensions
          else
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
    end

    register(:middleware, "ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch",
             Middleware::Probe.new)
  end
end
