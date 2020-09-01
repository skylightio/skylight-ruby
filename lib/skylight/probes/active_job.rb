module Skylight
  module Probes
    module ActiveJob
      TITLE = "ActiveJob.execute".freeze

      module Instrumentation
        def execute(*)
          Skylight.trace(TITLE, "app.job.execute", component: :worker) do |trace|
          # See normalizers/active_job/perform for endpoint/segment assignment
            super
          rescue Exception
            trace.segment = "error" if trace
            raise
          end
        end
      end

      class Probe
        def install
          ::ActiveJob::Base.singleton_class.prepend(Instrumentation)
        end
      end
    end

    register(:active_job, "ActiveJob::Base", "active_job/base", ActiveJob::Probe.new)
  end
end
