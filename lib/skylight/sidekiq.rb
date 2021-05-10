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

      def call(worker, job, queue)
        t { "Sidekiq middleware beginning trace" }
        title = job["wrapped"] || job["class"]

        # TODO: Using hints here would be ideal but requires further refactoring
        meta =
          if (source_location = worker.method(:perform).source_location)
            { source_file: source_location[0], source_line: source_location[1] }
          end

        Skylight.trace(title, "app.sidekiq.worker", title, meta: meta, segment: queue, component: :worker) do |trace|
          yield
        rescue Exception # includes Sidekiq::Shutdown
          trace.segment = "error" if trace
          raise
        end
      end
    end

    ActiveSupport::Notifications.subscribe(
      "started_instrumenter.skylight"
    ) do |_name, _started, _finished, _unique_id, payload|
      add_middleware if payload[:instrumenter].config.enable_sidekiq?
    end
  end
end
