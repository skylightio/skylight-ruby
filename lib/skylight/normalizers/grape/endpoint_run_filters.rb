module Skylight
  module Normalizers
    module Grape
      class EndpointRunFilters < Endpoint
        register "endpoint_run_filters.grape"

        CAT = "app.grape.filters".freeze

        def normalize(_trace, _name, payload)
          filters = payload[:filters]
          type = payload[:type]

          return :skip if (!filters || filters.empty?) || !type

          [CAT, "#{type.to_s.capitalize} Filters", nil]
        end
      end
    end
  end
end
