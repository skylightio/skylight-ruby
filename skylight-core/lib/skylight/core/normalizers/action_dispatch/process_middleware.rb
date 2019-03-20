module Skylight::Core
  module Normalizers
    module ActionDispatch
      class ProcessMiddleware < Normalizer
        register "process_middleware.action_dispatch"

        CAT = "rack.middleware".freeze
        ANONYMOUS_MIDDLEWARE = "Anonymous Middleware".freeze
        ANONYMOUS = /\A#<(Class|Module|Proc):/

        def normalize(trace, _name, payload)
          Skylight::Core::Probes::Middleware::Probe.disable!
          name = payload[:middleware].to_s
          name = ANONYMOUS_MIDDLEWARE if name[ANONYMOUS]
          trace.endpoint = name
          [CAT, name, nil]
        end
      end
    end
  end
end
