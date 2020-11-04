module Skylight
  module Probes
    module ActiveJob
      class EnqueueProbe
        CAT = "other.active_job.enqueue".freeze

        def install
          ::ActiveJob::Base.around_enqueue do |job, block|
            job_class = job.class
            adapter_name = EnqueueProbe.normalize_adapter_name(job_class)

            # If this is an ActionMailer::DeliveryJob, we'll report this as the mailer title
            # and include ActionMailer::DeliveryJob in the description.
            name, job_class_name = Normalizers::ActiveJob::Perform.normalize_title(job)
            descriptors = ["adapter: '#{adapter_name}'", "queue: '#{job.queue_name}'"]
            descriptors << "job: '#{job_class_name}'" if job_class_name
            desc = "{ #{descriptors.join(', ')} }"
          rescue
            block.call
          else
            Skylight.instrument(
              title: "Enqueue #{name}",
              category: CAT,
              description: desc,
              internal: true,
              &block
            )
          end

          self.class.instance_eval do
            def normalize_adapter_name(job_class)
              job_class.queue_adapter_name
            end
          end
        end
      end
    end

    register(:active_job_enqueue, "ActiveJob::Base", "active_job/base", ActiveJob::EnqueueProbe.new)
  end
end
