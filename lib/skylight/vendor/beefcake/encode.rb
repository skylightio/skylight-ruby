require 'skylight/vendor/beefcake/buffer'

module Skylight
  module Beefcake
    class Buffer

      def append(type, val, fn)
        if fn != 0
          wire = Buffer.wire_for(type)
          append_info(fn, wire)
        end

        __send__("append_#{type}", val)
      end

      def append_info(fn, wire)
        append_uint32((fn << 3) | wire)
      end

      def append_fixed32(n, tag=false)
        if n < MinUint32 || n > MaxUint32
          raise OutOfRangeError, n
        end

        self << [n].pack("V")
      end

      def append_fixed64(n)
        if n < MinUint64 || n > MaxUint64
          raise OutOfRangeError, n
        end

        self << [n & 0xFFFFFFFF, n >> 32].pack("VV")
      end

      def append_int32(n)
        if n < MinInt32 || n > MaxInt32
          raise OutOfRangeError, n
        end

        append_int64(n)
      end

      def append_uint32(n)
        if n < MinUint32 || n > MaxUint32
          raise OutOfRangeError, n
        end

        append_uint64(n)
      end

      def append_int64(n)
        if n < MinInt64 || n > MaxInt64
          raise OutOfRangeError, n
        end

        if n < 0
          n += (1 << 64)
        end

        append_uint64(n)
      end

      def append_sint32(n)
        append_uint32((n << 1) ^ (n >> 31))
      end

      def append_sfixed32(n)
        append_fixed32((n << 1) ^ (n >> 31))
      end

      def append_sint64(n)
        append_uint64((n << 1) ^ (n >> 63))
      end

      def append_sfixed64(n)
        append_fixed64((n << 1) ^ (n >> 63))
      end

      def append_uint64(n)
        if n < MinUint64 || n > MaxUint64
          raise OutOfRangeError, n
        end

        while true
          bits = n & 0x7F
          n >>= 7
          if n == 0
            return self << bits
          end
          self << (bits | 0x80)
        end
      end

      def append_float(n)
        self << [n].pack("e")
      end

      def append_double(n)
        self << [n].pack("E")
      end

      def append_bool(n)
        append_int64(n ? 1 : 0)
      end

      def append_string(s)
        append_uint64(s.length)
        self << s
      end
      alias :append_bytes :append_string

    end
  end
end
