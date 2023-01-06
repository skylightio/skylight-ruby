module Skylight
  module Normalizers
    module ActiveJob
      class Perform < Normalizer
        register "perform.active_job"

        DELIVERY_JOB = /\AActionMailer::(Mail)?DeliveryJob\Z/.freeze
        DELAYED_JOB_WRAPPER = "ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper".freeze

        def self.normalize_title(job_instance)
          job_instance.class.name.to_s.tap do |str|
            if str.match(DELIVERY_JOB)
              mailer_class, mailer_method, * = job_instance.arguments
              return "#{mailer_class}##{mailer_method}", str if mailer_class && mailer_method
            end
          end
        end

        CAT = "app.job.perform".freeze

        def normalize(trace, _name, payload)
          title = payload[:job].class.to_s
          adapter_name = normalize_adapter_name(payload[:adapter])
          desc = "{ adapter: '#{adapter_name}', queue: '#{payload[:job].queue_name}' }"

          maybe_set_endpoint(trace, payload)

          [CAT, title, desc]
        end

        def normalize_after(trace, _span, _name, payload)
          maybe_set_endpoint(trace, payload)
        end

        private

        def process_meta_options(payload)
          # provide hints to override default source_location behavior
          super.merge(source_location_hint: [:instance_method, payload[:job].class.to_s, "perform"])
        end

        def normalize_adapter_name(adapter)
          adapter_string = adapter.is_a?(Class) ? adapter.to_s : adapter.class.to_s
          adapter_string[/ActiveJob::QueueAdapters::(\w+)Adapter/, 1].underscore
        rescue StandardError
          "active_job"
        end

        def maybe_set_endpoint(trace, payload)
          endpoint = normalize_title(payload[:job])

          # Always assign the endpoint if it has not yet been assigned by the ActiveJob probe.
          if !trace.endpoint ||
               (defined?(Skylight::Probes::ActiveJob::TITLE) && trace.endpoint == Skylight::Probes::ActiveJob::TITLE) ||
               (
                 defined?(Skylight::Probes::DelayedJob::Probe::UNKNOWN) &&
                   trace.endpoint == Skylight::Probes::DelayedJob::Probe::UNKNOWN
               ) ||
               # If a job is called using #perform_now inside a controller action
               # or within another job's #perform method, we do not want this to
               # overwrite the existing endpoint name (unless it is the default from ActiveJob).
               #
               # If the current endpoint name matches this payload, return true to allow the
               # segment to be assigned by normalize_after.
               trace.endpoint =~ DELIVERY_JOB ||
               # This adapter wrapper needs to be handled specifically due to interactions with the
               # standalone Delayed::Job probe, as there is no consistent way to get the wrapped
               # job name among all Delayed::Job backends.
               trace.endpoint == DELAYED_JOB_WRAPPER
            trace.endpoint = endpoint
          end

          trace.segment = payload[:job].queue_name if trace.endpoint == endpoint && config.enable_segments?
        end

        def normalize_title(job_instance)
          title, * = self.class.normalize_title(job_instance)
          title
        end
      end
    end
  end
end
