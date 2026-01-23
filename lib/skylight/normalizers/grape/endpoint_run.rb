module Skylight
  module Normalizers
    module Grape
      class EndpointRun < Endpoint
        register "endpoint_run.grape"

        def normalize(trace, _name, payload)
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
            path = "/#{path}" if path[0] != "/"
            path = "#{namespace}#{path}"
          end

          "#{base_app_name(endpoint)} [#{method}] #{path}".strip
        end

        def base_app_name(endpoint)
          ep = endpoint.options[:for]
          return ep.name if ep.name

          if ep.respond_to?(:base) && ep.base.respond_to?(:name)
            ep.base.name
          elsif ep.respond_to?(:to_s)
            # grape >= 3.1 removes the `base` attr_reader but delegates to_s to :@base
            ep.to_s
          end
        end
      end
    end
  end
end
