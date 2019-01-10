module Skylight::Core
  module Probes
    module ActiveJob
      class Probe
        TITLE = "ActiveJob.execute".freeze

        def install
          ::ActiveJob::Base.instance_eval do
            alias execute_without_sk execute

            def execute(*args)
              Skylight.trace(TITLE, "app.job.execute") do |trace|
                # See normalizers/active_job/perform for endpoint/segment assignment
                begin
                  execute_without_sk(*args)
                rescue Exception
                  trace.segment = "error" if trace
                  raise
                end
              end
            end
          end
        end
      end
    end

    register(:active_job, "ActiveJob::Base", "active_job/base", ActiveJob::Probe.new)
  end
end
