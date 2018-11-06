module Skylight::Core
  module Probes
    module DelayedJob
      class Probe
        def install
          return unless validate_version
          ::Delayed::Worker.class_eval do
            include Skylight::Core::Util::Logging
            alias run_without_sk run
            alias handle_failed_job_without_sk handle_failed_job
            # alias payload_object_without_sk payload_object

            # def run(job)
            #   job_say job, 'RUNNING'
            #   runtime = Benchmark.realtime do
            #     Timeout.timeout(max_run_time(job).to_i, WorkerTimeout) { job.invoke_job }
            #     job.destroy
            #   end
            #   job_say job, format('COMPLETED after %.4f', runtime)
            #   return true # did work
            # rescue DeserializationError => error
            #   job_say job, "FAILED permanently with #{error.class.name}: #{error.message}", 'error'

            #   job.error = error
            #   failed(job)
            # rescue Exception => error # rubocop:disable RescueException
            #   self.class.lifecycle.run_callbacks(:error, self, job) { handle_failed_job(job, error) }
            #   return false # work failed
            # end

            def run(job, *args)
              t { 'Delayed::Job beginning trace' }
              Skylight.trace(job.name, 'app.delayed_job.worker', 'Delayed::Worker#run', segment: job.queue) do
                run_without_sk(job, *args)
              end
            end

            def handle_failed_job(job, error, *args)
              handle_failed_job_without_sk(job, error, *args)
              return unless Skylight.trace
              Skylight.trace.segment = 'error'
            end
          end
        end

        private

        def validate_version
          spec = Gem.loaded_specs['delayed_job']
          version = spec && spec.version

          if !version || version < Gem::Version.new('4.0.0')
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
