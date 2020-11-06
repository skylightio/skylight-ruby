require "skylight/formatters/http"

module Skylight
  module Probes
    module Excon
      # Middleware for Excon that instruments requests
      class Middleware < ::Excon::Middleware::Base
        def initialize(*)
          @requests = {}.compare_by_identity
          super
        end

        # TODO: Review the following:
        # - Consider whether a LIFO queue would be sufficient
        # - Check that errors can't be called without a request

        def request_call(datum)
          begin_instrumentation(datum)
          super
        end

        def response_call(datum)
          super
        ensure
          end_instrumentation(datum)
        end

        def error_call(datum)
          super
        ensure
          end_instrumentation(datum)
        end

        private

          def begin_instrumentation(datum)
            method = datum[:method].to_s
            scheme = datum[:scheme]
            host   = datum[:host]
            # TODO: Maybe don't show other default ports like 443
            port   = datum[:port] != 80 ? datum[:port] : nil
            path   = datum[:path]
            query  = datum[:query]

            opts = Formatters::HTTP.build_opts(method, scheme, host, port, path, query)

            @requests[datum] = Skylight.instrument(opts)
          rescue Exception => e
            Skylight.error "failed to begin instrumentation for Excon; msg=%s", e.message
          end

          def end_instrumentation(datum)
            if (request = @requests.delete(datum))
              meta = {}
              if datum[:error].is_a?(Exception)
                meta[:exception_object] = datum[:error]
              end
              Skylight.done(request, meta)
            end
          rescue Exception => e
            Skylight.error "failed to end instrumentation for Excon; msg=%s", e.message
          end
      end
    end
  end
end
