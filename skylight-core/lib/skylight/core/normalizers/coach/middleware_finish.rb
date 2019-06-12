module Skylight::Core
  module Normalizers
    module Coach
      class MiddlewareFinish < Normalizer
        register "finish_middleware.coach"

        CAT = "app.coach.middleware".freeze

        # See information on the events Coach emits here:
        # https://github.com/gocardless/coach#instrumentation

        # Called whenever a new middleware is executed. We can expect this to happen
        # within a Coach::Handler.
        #
        # We can expect the payload to have the :middleware key.
        def normalize(trace, _name, payload)
          trace.endpoint = payload[:middleware]
          [CAT, payload[:middleware], nil]
        end
      end
    end
  end
end
