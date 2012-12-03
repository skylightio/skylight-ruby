module Skylight
  module Util
    class UUID
      BYTE_SIZE   = 16
      PREFIX_SIZE = 8

      def self.gen(prefix = nil)
        if prefix == nil
          return SecureRandom.random_bytes(BYTE_SIZE)
        end

        if prefix.bytesize > PREFIX_SIZE
          raise "UUID prefix must be less than 8 bytes"
        end

        # Does not fully conform with the spec
        rnd = SecureRandom.random_bytes(BYTE_SIZE - prefix.bytesize)
        new "#{prefix}#{rnd}"
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
