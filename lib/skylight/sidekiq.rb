module Skylight
  module Sidekiq
    def self.add_middleware
      unless defined?(::Sidekiq)
        Skylight.warn "Skylight for Sidekiq is active, but Sidekiq is not defined."
        return
      end

      ::Sidekiq.configure_server do |sidekiq_config|
        Skylight.debug "Adding Sidekiq Middleware"

        sidekiq_config.server_middleware do |chain|
          # Put it at the front
          chain.prepend ServerMiddleware
        end
      end
    end

    class ServerMiddleware
      include Util::Logging

      def call(_worker, job, queue)
        t { "Sidekiq middleware beginning trace" }
        title = job["wrapped"] || job["class"]
        Skylight.trace(title, "app.sidekiq.worker", title, segment: queue, component: :worker) do |trace|
          yield
        rescue Exception # includes Sidekiq::Shutdown
          trace.segment = "error" if trace
          raise
        end
      end
    end

    ActiveSupport::Notifications.subscribe("started_instrumenter.skylight") \
        do |_name, _started, _finished, _unique_id, payload|
      if payload[:instrumenter].config.enable_sidekiq?
        add_middleware
      end
    end
  end
end
