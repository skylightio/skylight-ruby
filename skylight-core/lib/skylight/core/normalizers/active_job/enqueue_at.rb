module Skylight::Core
  module Normalizers
    module ActiveJob
      class EnqueueAt < Normalizer
        register "enqueue_at.active_job"

        CAT = "other.job.enqueue_at".freeze

        def normalize(_trace, _name, payload, _instrumenter)
					title = "Enqueue #{payload[:job].class}"

					adapter_class_name = payload[:adapter].class.name
					adapter_name = adapter_class_name.match(/^ActiveJob::QueueAdapters::(\w+)Adapter$/)[1].underscore
					desc = "{ adapter: '#{adapter_name}', queue: '#{payload[:job].queue_name}' }"

					[ CAT, title, desc ]
        end
      end
    end
  end
end
