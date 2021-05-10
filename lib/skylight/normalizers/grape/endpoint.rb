module Skylight
  module Normalizers
    module Grape
      class Endpoint < Normalizer
        %w[run render run_filters].each { |type| require "skylight/normalizers/grape/endpoint_#{type}" }

        require "skylight/normalizers/grape/format_response"

        private

        def get_method(endpoint)
          method = endpoint.options[:method].first
          method = "#{method}..." if endpoint.options[:method].length > 1
          method
        end

        def get_path(endpoint)
          endpoint.options[:path].join("/")
        end

        def get_namespace(endpoint)
          # slice off preceding slash for data continuity
          ::Grape::Namespace.joined_space_path(endpoint.namespace_stackable(:namespace)).to_s[1..-1]
        end
      end
    end
  end
end
