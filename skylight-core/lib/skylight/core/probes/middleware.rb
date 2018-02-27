module Skylight::Core
  module Probes
    module Middleware
      class Probe
        def self.add_instrumentation(middleware, default_name: "Anonymous Middleware", category: "rack.middleware")
          middleware.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
            alias call_without_sk call
            def call(*args, &block)
              traces = Skylight::Core::Fanout.registered.map do |r|
                r.instrumenter ? r.instrumenter.current_trace : nil
              end.compact

              return call_without_sk(*args, &block) if traces.empty?

              begin
                name = self.class.name || "#{default_name}"

                traces.each{|t| t.endpoint = name }

                spans = Skylight::Core::Fanout.instrument(title: name, category: "#{category}")
                resp = call_without_sk(*args, &block)

                Skylight::Core::Middleware.with_after_close(resp) do
                  Skylight::Core::Fanout.done(spans)
                end
              rescue Exception => e
                # FIXME: Log this?
                Skylight::Core::Fanout.done(spans, exception_object: e)
                raise
              end
            end
          RUBY
        end

        def install
          ActionDispatch::MiddlewareStack.class_eval do
            alias build_without_sk build

            if ::ActionPack.gem_version >= Gem::Version.new('5.x')
              # Rails 5
              def build(app = Proc.new)
                Skylight::Core::Probes::Middleware::Probe.add_instrumentation(app, default_name: "Rack App", category: "rack.app")
                build_without_sk(app)
              end
            else
              # Rails 3 and 4
              def build(app, &block)
                app ||= block
                raise "MiddlewareStack#build requires an app" unless app
                Skylight::Core::Probes::Middleware::Probe.add_instrumentation(app, default_name: "Rack App", category: "rack.app")
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
              return middleware if middleware.is_a?(Skylight::Core::Middleware)

              # Not sure how this would actually happen
              return middleware if middleware.respond_to?(:call_without_sk)

              # On Rails 3, ActionDispatch::Session::CookieStore is frozen, for one
              return middleware if middleware.frozen?

              Skylight::Core::Probes::Middleware::Probe.add_instrumentation(middleware)

              middleware
            end
          end
        end
      end
    end

    register("ActionDispatch::MiddlewareStack::Middleware", "actionpack/action_dispatch", Middleware::Probe.new)
  end
end
