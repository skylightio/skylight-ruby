module Skylight
  module Normalizers
    module Coach
      class MiddlewareFinish < Normalizer
        begin
          require "coach/version"
          version = Gem::Version.new(::Coach::VERSION)
        rescue LoadError # rubocop:disable Lint/HandleExceptions
        end

        if version && version < Gem::Version.new("1.0")
          register "coach.middleware.finish"
        else
          register "finish_middleware.coach"
        end

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
