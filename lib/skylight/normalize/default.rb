module Skylight
  module Normalize
    class Default < Normalizer
      REGEX = /^(?:#{TIERS.join('|')})(?:\.|$)/

      def normalize
        if @name =~ REGEX
          annot = @payload.dup
          [ @name, annot.delete(:title), annot.delete(:description), annot ]
        else
          :skip
        end
      end

    end
  end
end
