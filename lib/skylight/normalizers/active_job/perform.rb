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
              return ["#{mailer_class}##{mailer_method}", str]
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
          return unless config.enable_segments? && assign_endpoint?(trace, payload)

          trace.segment = payload[:job].queue_name
        end

        private

          def process_meta_options(payload)
            # provide hints to override default source_location behavior
            super.merge(source_location: [:instance_method, payload[:job].class.to_s, "perform"])
          end

          def normalize_adapter_name(adapter)
            adapter_string = adapter.is_a?(Class) ? adapter.to_s : adapter.class.to_s
            adapter_string[/ActiveJob::QueueAdapters::(\w+)Adapter/, 1].underscore
          rescue
            "active_job"
          end

          def maybe_set_endpoint(trace, payload)
            if assign_endpoint?(trace, payload)
              trace.endpoint = normalize_title(payload[:job])
            end
          end

          def assign_endpoint?(trace, payload)
            # Always assign the endpoint if it has not yet been assigned by the ActiveJob probe.
            return true unless trace.endpoint
            return true if defined?(Skylight::Probes::ActiveJob::TITLE) &&
                           trace.endpoint == Skylight::Probes::ActiveJob::TITLE
            return true if defined?(SKylight::Probes::DelayedJob::Probe::UNKNOWN) &&
                           trace.endpoint == Skylight::Probes::DelayedJob::Probe::UNKNOWN

            # If a job is called using #perform_now inside a controller action
            # or within another job's #perform method, we do not want this to
            # overwrite the existing endpoint name (unless it is the default from ActiveJob).
            #
            # If the current endpoint name matches this payload, return true to allow the
            # segment to be assigned by normalize_after.
            trace.endpoint == DELIVERY_JOB ||
              trace.endpoint == normalize_title(payload[:job]) ||
              # This adapter wrapper needs to be handled specifically due to interactions with the
              # standalone Delayed::Job probe, as there is no consistent way to get the wrapped
              # job name among all Delayed::Job backends.
              trace.endpoint == DELAYED_JOB_WRAPPER
          end

          def normalize_title(job_instance)
            title, * = self.class.normalize_title(job_instance)
            title
          end

          def process_meta_options(payload)
            # provide hints to override default source_location behavior
            super.merge(source_location_hint: [:instance_method, payload[:job].class.to_s, "perform"])
          end
      end
    end
  end
end
