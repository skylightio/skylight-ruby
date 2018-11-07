module Skylight
  module Core
    module Sidekiq
      def self.add_middleware(instrumentable)
        ::Sidekiq.configure_server do |sidekiq_config|
          instrumentable.debug "Adding Sidekiq Middleware"

          sidekiq_config.server_middleware do |chain|
            # Put it at the front
            chain.prepend ServerMiddleware, instrumentable
          end
        end
      end

      class ServerMiddleware
        include Util::Logging

        def initialize(instrumentable)
          @instrumentable = instrumentable
        end

        def call(_worker, job, queue)
          t { "Sidekiq middleware beginning trace" }
          title = job['wrapped'] || job['class']
          @instrumentable.trace(title, 'app.sidekiq.worker', title, segment: queue) do |trace|
            begin
              yield
            rescue Exception # includes Sidekiq::Shutdown
              trace.segment = 'error' if trace
              raise
            end
          end
        end
      end

      ActiveSupport::Notifications.subscribe("started_instrumenter.skylight") \
          do |_name, _started, _finished, _unique_id, payload|
        if payload[:instrumenter].config.enable_sidekiq?
          add_middleware(payload[:instrumenter])
        end
      end
    end
  end
end
