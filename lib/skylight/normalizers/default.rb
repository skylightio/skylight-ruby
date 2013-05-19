module Skylight
  module Normalizers
    class Default
      REGEX = /^(?:#{TIERS.join('|')})(?:\.|$)/

      def normalize(trace, name, payload)
        if name =~ REGEX
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
