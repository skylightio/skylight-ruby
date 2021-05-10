module Skylight
  module Normalizers
    # The default normalizer, used if no other is found.
    class Default < Normalizer
      def initialize
        super(nil) # Pass no config and handle it in new method
      end

      def config
        Skylight.config
      end

      # @param trace [Skylight::Messages::Trace::Builder] ignored, only present to match API
      # @param name [String]
      # @param payload [Hash]
      # @option payload [String] :title
      # @option payload [String] :description
      # @return [Array, :skip] the normalized array or `:skip` if `name` is not part of a known {Skylight::TIERS tier}
      def normalize(_trace, name, payload)
        name =~ Skylight::TIER_REGEX ? [name, payload[:title], payload[:description]] : :skip
      end
    end
  end
end
