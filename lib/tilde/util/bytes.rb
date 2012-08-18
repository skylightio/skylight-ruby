module Tilde
  module Util
    class OutOfRangeError < RuntimeError; end

    module Bytes
      # Helper consts
      MinUint64 =  0
      MaxUint64 =  (1<<64)-1
      MinInt64  = -(1<<63)
      MaxInt64  =  (1<<63)-1

      # varints
      def append_uint64(buf, n)
        if n < MinUint64 || n > MaxUint64
          raise OutOfRangeError, n
        end

        while true
          bits = n & 0x7F
          n >>= 7

          if n == 0
            return buf << bits
          end

          buf << (bits | 0x80)
        end
      end

      def str_bytesize(str)
        str.bytesize
      end

      def append_string(buf, str)
        append_uint64(buf, str_bytesize(str))
        buf << str
      end
    end
  end
end
