module Skylight
  module Probes
    module DelayedJob
      module Instrumentation
        include Skylight::Util::Logging

        def run(job, *)
          t { "Delayed::Job beginning trace" }

          handler_name =
            begin
              if defined?(::Delayed::PerformableMethod) && job.payload_object.is_a?(::Delayed::PerformableMethod)
                job.name
              else
                job.payload_object.class.name
              end
            rescue
              UNKNOWN
            end

          Skylight.trace(handler_name, "app.delayed_job.worker", "Delayed::Worker#run",
                         component: :worker, segment: job.queue) { super }
        end

        def handle_failed_job(*)
          super
          return unless Skylight.trace

          Skylight.trace.segment = "error"
        end
      end

      class Probe
        UNKNOWN = "<Delayed::Job Unknown>".freeze

        def install
          return unless validate_version

          ::Delayed::Worker.prepend(Instrumentation)
        end

        private

          def validate_version
            spec = Gem.loaded_specs["delayed_job"]
            version = spec&.version

            if !version || version < Gem::Version.new("4.0.0")
              Skylight.error "The installed version of DelayedJob is not supported on Skylight. " \
                             "Your jobs will not be tracked."

              return false
            end

            true
          end
      end
    end

    register(:delayed_job, "Delayed::Worker", "delayed_job", DelayedJob::Probe.new)
  end
end
