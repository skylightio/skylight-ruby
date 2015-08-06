module Skylight
  module Normalizers
    module Grape
      class EndpointRender < Endpoint
        register "endpoint_render.grape"

        CAT = "app.grape.endpoint".freeze

        def normalize(trace, name, payload)
          if endpoint = payload[:endpoint]
            path = get_path(endpoint)
            namespace = get_namespace(endpoint)
            method = get_method(endpoint)

            title = [method, namespace, path].join(' ').gsub(/\s+/, ' ')

            [CAT, title, nil]
          else
            :skip
          end
        end

      end
    end
  end
end
