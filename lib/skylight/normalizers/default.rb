module Skylight
  module Normalizers
    class Default

      def normalize(trace, name, payload)
        if name =~ TIER_REGEX
          annot = payload.dup
          [
            name,
            annot.delete(:title),
            annot.delete(:description),
            annot
          ]
        else
          :skip
        end
      end

    end
  end
end
