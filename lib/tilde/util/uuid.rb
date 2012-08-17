module Tilde
  module Util
    class UUID

      def self.gen
        # Does not fully conform with the spec
        new SecureRandom.random_bytes(16)
      end

      attr_reader :bytes

      def initialize(bytes)
        @bytes = bytes
      end

      def to_s
        @to_s ||= ""
      end

    end
  end
end
