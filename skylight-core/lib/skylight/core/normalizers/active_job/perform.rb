module Skylight::Core
  module Normalizers
    module ActiveJob
      class Perform < Normalizer
        register "perform.active_job"

        CAT = "app.job.perform".freeze

        def normalize(trace, _name, payload)
          title = payload[:job].class.to_s
          adapter_name = normalize_adapter_name(payload[:adapter])
          desc = "{ adapter: '#{adapter_name}', queue: '#{payload[:job].queue_name}' }"

          maybe_set_endpoint(trace, title)

          [CAT, title, desc]
        end

        def normalize_after(trace, _span, _name, payload)
          return unless config.enable_segments?
          trace.segment = payload[:job].queue_name
        end

        private

          def normalize_adapter_name(adapter)
            adapter_string = adapter.is_a?(Class) ? adapter.to_s : adapter.class.to_s
            adapter_string[/ActiveJob::QueueAdapters::(\w+)Adapter/, 1].underscore
          rescue
            "active_job"
          end

          def maybe_set_endpoint(trace, string)
            trace.endpoint ||= string

            # If a job is called using #perform_now inside a controller action
            # or within another job's #perform method, we do not want this to
            # overwrite the existing endpoint name (unless it is the default from ActiveJob).
            return unless trace.endpoint == Skylight::Core::Probes::ActiveJob::Probe::TITLE
            trace.endpoint = string
          end
      end
    end
  end
end
