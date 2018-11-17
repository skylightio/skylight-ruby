module Skylight::Core
  module Normalizers
    module Coach
      class MiddlewareFinish < Normalizer
        register "coach.middleware.finish"

        CAT = "app.coach.middleware".freeze

        # See information on the events Coach emits here:
        # https://github.com/gocardless/coach#instrumentation

        # Called whenever a new middleware is executed. We can expect this to happen
        # within a Coach::Handler.
        #
        # We can expect the payload to have the :middleware key.
        def normalize(trace, name, payload)
          trace.endpoint = payload[:middleware]
          [CAT, payload[:middleware], nil]
        end
      end
    end
  end
end
