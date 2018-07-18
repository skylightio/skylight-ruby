module Skylight::Core
  module Probes
    module ActiveJob
      class EnqueueProbe
        CAT = "other.active_job.enqueue".freeze

        def install
          ::ActiveJob::Base.around_enqueue do |job, block|
            begin
              job_class = job.class
              adapter_name = EnqueueProbe.normalize_adapter_name(job_class)
              desc = "{ adapter: #{adapter_name}, queue: '#{job.queue_name}' }"
              name = job_class.name
            rescue
              block.call
            else
              Skylight::Core::Fanout.instrument(
                title: "Enqueue #{name}", category: CAT, description: desc, &block
              )
            end
          end

          self.class.instance_eval do
            if ::ActiveJob.gem_version >= Gem::Version.new('5.2')
              def normalize_adapter_name(job_class)
                job_class.queue_adapter_name
              end
            else
              def normalize_adapter_name(job_class)
                adapter_class = job_class.queue_adapter.is_a?(Class) ? job_class.queue_adapter : job_class.queue_adapter.class
                adapter_class.name.demodulize.remove('Adapter').underscore
              end
            end
          end
        end
      end
    end

    register(:active_job_enqueue, "ActiveJob::Base", "active_job/base", ActiveJob::EnqueueProbe.new)
  end
end
