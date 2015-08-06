module Skylight
  module Normalizers
    module Grape
      class EndpointRun < Endpoint
        register "endpoint_run.grape"

        def normalize(trace, name, payload)
          trace.endpoint = get_endpoint_name(payload[:endpoint]) if payload[:endpoint]

          # We don't necessarily want this to be all instrumented since it's fairly internal.
          # However, it is a good place to get the endpoint name.
          :skip
        end

        private

          def get_endpoint_name(endpoint)
            method = get_method(endpoint)
            path = get_path(endpoint)
            namespace = get_namespace(endpoint)

            if namespace && !namespace.empty?
              path = "/#{path}" if path[0] != '/'
              path = "#{namespace}#{path}"
            end

            "#{endpoint.options[:for]} [#{method}] #{path}"
          end

      end
    end
  end
end
