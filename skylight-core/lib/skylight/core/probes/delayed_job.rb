module Skylight::Core
  module Probes
    module DelayedJob
      class Probe
        def install
          return unless validate_version
          ::Delayed::Worker.class_eval do
            include Skylight::Core::Util::Logging
            alias_method :run_without_sk, :run
            alias_method :handle_failed_job_without_sk, :handle_failed_job

            def run(job, *args)
              t { "Delayed::Job beginning trace" }
              Skylight.trace(job.name, "app.delayed_job.worker", "Delayed::Worker#run", segment: job.queue) do
                run_without_sk(job, *args)
              end
            end

            def handle_failed_job(job, error, *args)
              handle_failed_job_without_sk(job, error, *args)
              return unless Skylight.trace
              Skylight.trace.segment = "error"
            end
          end
        end

        private

          def validate_version
            spec = Gem.loaded_specs["delayed_job"]
            version = spec && spec.version

            if !version || version < Gem::Version.new("4.0.0")
              $stderr.puts "[SKYLIGHT::CORE] [#{Skylight::Core::VERSION}] The installed version of DelayedJob is not supported on Skylight. Your jobs will not be tracked."

              return false
            end

            true
          end
      end
    end

    register(:delayed_job, "Delayed::Worker", "delayed_job", DelayedJob::Probe.new)
  end
end
