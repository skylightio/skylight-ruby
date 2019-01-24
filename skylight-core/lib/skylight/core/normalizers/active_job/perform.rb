module Skylight::Core
  module Normalizers
    module ActiveJob
      class Perform < Normalizer
        register "perform.active_job"

        CAT = "app.job.perform".freeze

        def normalize(trace, _name, payload)
          title = normalize_title(payload[:job])
          adapter_name = normalize_adapter_name(payload[:adapter])
          desc = "{ adapter: '#{adapter_name}', queue: '#{payload[:job].queue_name}' }"

          trace.endpoint = title if assign_endpoint?(trace, payload)

          [ CAT, title, desc ]
        end

        def normalize_after(trace, _span, _name, payload)
          return unless config.enable_segments? && assign_endpoint?(trace, payload)

          trace.endpoint += "<sk-segment>#{payload[:job].queue_name}</sk-segment>"
        end

        private

        def normalize_adapter_name(adapter)
          adapter_string = adapter.is_a?(Class) ? adapter.to_s : adapter.class.to_s
          adapter_string[/ActiveJob::QueueAdapters::(\w+)Adapter/, 1].underscore
        rescue
          'active_job'
        end

        def assign_endpoint?(trace, payload)
          return false unless defined?(Skylight::Core::Probes::ActiveJob::Probe::TITLE)

          trace.endpoint == Skylight::Core::Probes::ActiveJob::Probe::TITLE ||
            trace.endpoint == normalize_title(payload[:job])
        end

        def normalize_title(job_instance)
          "#{job_instance.class}"
        end
      end
    end
  end
end
