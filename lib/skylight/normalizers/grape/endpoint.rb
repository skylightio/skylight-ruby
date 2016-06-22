module Skylight
  module Normalizers
    module Grape
      class Endpoint < Normalizer
        %w(run
            render
            run_filters).each do |type|
          require "skylight/normalizers/grape/endpoint_#{type}"
        end

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
            ::Grape::Namespace.joined_space(endpoint.namespace_stackable(:namespace))
          end

      end
    end
  end
end