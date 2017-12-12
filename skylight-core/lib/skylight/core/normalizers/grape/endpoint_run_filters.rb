module Skylight::Core
  module Normalizers
    module Grape
      class EndpointRunFilters < Endpoint
        register "endpoint_run_filters.grape"

        CAT = "app.grape.filters".freeze

        def normalize(trace, name, payload, instrumenter)
          filters = payload[:filters]
          type = payload[:type]

          if (!filters || filters.empty?) || !type
            return :skip
          end

          [CAT, "#{type.to_s.capitalize} Filters", nil]
        end

      end
    end
  end
end
