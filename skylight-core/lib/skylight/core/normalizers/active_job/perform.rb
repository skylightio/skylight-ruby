module Skylight::Core
  module Normalizers
    module ActiveJob
      class Perform < Normalizer
        register "perform.active_job"

        CAT = "app.job.perform".freeze

        def normalize(trace, _name, payload)
          title = "#{payload[:job].class}"

          adapter_class_name = payload[:adapter].class.name
          adapter_name = adapter_class_name.match(/^ActiveJob::QueueAdapters::(\w+)Adapter$/)[1].underscore
          desc = "{ adapter: '#{adapter_name}', queue: '#{payload[:job].queue_name}' }"

          trace.endpoint = title

          [ CAT, title, desc ]
        end

        def normalize_after(trace, span, name, payload)
          return unless config.enable_segments?
          trace.endpoint += "<sk-segment>#{payload[:job].queue_name}</sk-segment>"
        end
      end
    end
  end
end
