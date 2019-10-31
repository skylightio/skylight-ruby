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

              # If this is an ActionMailer::DeliveryJob, we'll report this as the mailer title
              # and include ActionMailer::DeliveryJob in the description.
              name, job_class_name = Skylight::Core::Normalizers::ActiveJob::Perform.normalize_title(job)
              descriptors = ["adapter: '#{adapter_name}'", "queue: '#{job.queue_name}'"]
              descriptors << "job: '#{job_class_name}'" if job_class_name
              desc = "{ #{descriptors.join(', ')} }"
            rescue
              block.call
            else
              Skylight::Fanout.instrument(
                title: "Enqueue #{name}", category: CAT, description: desc, &block
              )
            end
          end

          self.class.instance_eval do
            if ::ActiveJob.gem_version >= Gem::Version.new("5.2")
              def normalize_adapter_name(job_class)
                job_class.queue_adapter_name
              end
            else
              def normalize_adapter_name(job_class)
                adapter_class = job_class.queue_adapter.is_a?(Class) ? job_class.queue_adapter : job_class.queue_adapter.class
                adapter_class.name.demodulize.remove("Adapter").underscore
              end
            end
          end
        end
      end
    end

    register(:active_job_enqueue, "ActiveJob::Base", "active_job/base", ActiveJob::EnqueueProbe.new)
  end
end
