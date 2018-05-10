module Skylight::Core
  module Normalizers
    module Grape
      class FormatResponse < Normalizer
        register "format_response.grape"

        CAT = "view.grape.format_response".freeze

        def normalize(_trace, _name, payload)
          if (formatter = payload[:formatter])
            title = formatter.is_a?(Module) ?  formatter.to_s : formatter.class.to_s
            [CAT, title, nil]
          else
            :skip
          end
        end

      end
    end
  end
end
