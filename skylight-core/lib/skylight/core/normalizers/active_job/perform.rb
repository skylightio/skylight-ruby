module Skylight::Core
  module Normalizers
    module ActiveJob
      class Perform < Normalizer
        register "perform.active_job"

        CAT = "app.job.perform".freeze

        def normalize(trace, _name, payload)
          title = (payload[:job].class).to_s
          adapter_name = normalize_adapter_name(payload[:adapter])
          desc = "{ adapter: '#{adapter_name}', queue: '#{payload[:job].queue_name}' }"

          trace.endpoint = title

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
      end
    end
  end
end
