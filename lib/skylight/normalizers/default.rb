module Skylight
  module Normalizers
    class Default

      def normalize(trace, name, payload)
        if name =~ TIER_REGEX
          [
            name,
            payload[:title],
            payload[:description]
          ]
        else
          :skip
        end
      end

    end
  end
end
