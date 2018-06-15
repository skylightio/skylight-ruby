module Skylight::Core
  module Probes
    module ActiveJob
      class EnqueueProbe
        CAT = "other.active_job.enqueue".freeze

        def install
          ::ActiveJob::Base.around_enqueue do |job, block|
            begin
              desc = "{ adapter: #{job.class.queue_adapter_name}, queue: '#{job.queue_name}' }"
              name = job.class.name
            rescue
              block.call
            else
              Skylight::Core::Fanout.instrument(
                title: "Enqueue #{name}", category: CAT, description: desc, &block
              )
            end
          end
        end

      end
    end

    register(:active_job_enqueue, "ActiveJob::Base", "active_job/base", ActiveJob::EnqueueProbe.new)
  end
end
