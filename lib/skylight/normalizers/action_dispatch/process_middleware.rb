# frozen_string_literal: true

module Skylight
  module Normalizers
    module ActionDispatch
      class ProcessMiddleware < Normalizer
        register "process_middleware.action_dispatch"

        CAT = "rack.middleware"
        ANONYMOUS_MIDDLEWARE = "Anonymous Middleware"
        ANONYMOUS = /\A#<(Class|Module|Proc):/.freeze

        def normalize(trace, _name, payload)
          name = payload[:middleware].to_s
          name = ANONYMOUS_MIDDLEWARE if name[ANONYMOUS]
          trace.endpoint = name
          [CAT, name, nil]
        end

        def source_location(trace, _name, payload, cache_key: nil)
          return unless trace.config.enable_source_locations?

          payload[:sk_source_location]
        end
      end
    end
  end
end
