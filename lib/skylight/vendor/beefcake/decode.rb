require 'skylight/vendor/beefcake/buffer'

module Skylight
  module Beefcake
    class Buffer

      def read_info
        n    = read_uint64
        fn   = n >> 3
        wire = n & 0x7

        [fn, wire]
      end

      def read_string
        read(read_uint64)
      end
      alias :read_bytes :read_string

      def read_fixed32
        bytes = read(4)
        bytes.unpack("V").first
      end

      def read_fixed64
        bytes = read(8)
        x, y = bytes.unpack("VV")
        x + (y << 32)
      end

      def read_int64
        n = read_uint64
        if n > MaxInt64
          n -= (1 << 64)
        end
        n
      end
      alias :read_int32 :read_int64

      def read_uint64
        n = shift = 0
        while true
          if shift >= 64
            raise BufferOverflowError, "varint"
          end
          b = buf.slice!(0)

          ## 1.8.6 to 1.9 Compat
          if b.respond_to?(:ord)
            b = b.ord
          end

          n |= ((b & 0x7F) << shift)
          shift += 7
          if (b & 0x80) == 0
            return n
          end
        end
      end
      alias :read_uint32 :read_uint64

      def read_sint64
        decode_zigzag(read_uint64)
      end
      alias :read_sint32 :read_sint64

      def read_sfixed32
        decode_zigzag(read_fixed32)
      end

      def read_sfixed64
        decode_zigzag(read_fixed64)
      end

      def read_float
        bytes = read(4)
        bytes.unpack("e").first
      end

      def read_double
        bytes = read(8)
        bytes.unpack("E").first
      end

      def read_bool
        read_int32 != 0
      end

      def skip(wire)
        case wire
        when 0 then read_uint64
        when 1 then read_fixed64
        when 2 then read_string
        when 5 then read_fixed32
        end
      end


      private

      def decode_zigzag(n)
        (n >> 1) ^ -(n & 1)
      end

    end
  end
end
