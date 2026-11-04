module Skylight
  module Normalizers
    module Grape
      class Endpoint < Normalizer
        %w[run render run_filters].each { |type| require "skylight/normalizers/grape/endpoint_#{type}" }

        require "skylight/normalizers/grape/format_response"

        private

        def get_method(endpoint)
          methods = http_methods(endpoint)
          method = methods.first
          method = "#{method}..." if methods.length > 1
          method
        end

        def get_path(endpoint)
          paths(endpoint).join("/")
        end

        # Grape 4+ no longer keeps an endpoint's methods, paths and API in `options`

        def http_methods(endpoint)
          # There's no public reader for these. Routes have them, but the endpoint here
          # is a per-request copy that rebuilds its routes on every call, and automatic
          # OPTIONS and 405 responses run on a route that has no endpoint to ask.
          endpoint.options[:method] || endpoint.send(:config).http_methods
        end

        def paths(endpoint)
          endpoint.options[:path] ||
            # Grape 4.0 has no public reader for these (Endpoint#path arrived in 4.1)
            (endpoint.respond_to?(:path) ? endpoint.path : endpoint.send(:config).path)
        end

        def api(endpoint)
          endpoint.options[:for] || endpoint.api
        end

        def get_namespace(endpoint)
          if endpoint.respond_to?(:namespace_stackable)
            # Grape 2.x
            ::Grape::Namespace.joined_space_path(endpoint.namespace_stackable(:namespace)).to_s[1..]
          else
            # Grape 3.x
            endpoint.namespace.to_s[1..]
          end
        end
      end
    end
  end
end
