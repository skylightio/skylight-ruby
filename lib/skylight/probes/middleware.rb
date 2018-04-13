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

              Skylight::Middleware.with_after_close(resp) { trace.done(span) }
            rescue Exception
              # FIXME: Log this?
              trace.done(span)
              raise
            end
          end
        RUBY
      end

      class Probe

        def install
          ActionDispatch::MiddlewareStack.class_eval do
            alias build_without_sk build

            if ::ActionPack.respond_to?(:gem_version) && ::ActionPack.gem_version >= Gem::Version.new('5.x')
              # Rails 5
              def build(app = Proc.new)
                Skylight::Probes::Middleware.add_instrumentation(app, "Rack App", "rack.app")
                build_without_sk(app)
              end
            else
              # Rails 3 and 4
              def build(app, &block)
                app ||= block
                raise "MiddlewareStack#build requires an app" unless app
                Skylight::Probes::Middleware.add_instrumentation(app, "Rack App", "rack.app")
                build_without_sk(app)
              end
            end
          end

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
