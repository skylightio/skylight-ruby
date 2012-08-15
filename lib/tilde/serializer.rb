module Tilde
  class Serializer
    PROTO_VERSION    = 1
    TRACE_MESSAGE_ID = [0].pack('C').freeze

    # Helper consts
    MinUint64 =  0
    MaxUint64 =  (1<<64)-1
    MinInt64  = -(1<<63)
    MaxInt64  =  (1<<63)-1

    class OutOfRangeError < RuntimeError; end

    class Iterator
      attr_reader :sample

      def initialize(serializer, sample)
        @serialize = serializer
        @sample = sample
      end

      def each
        yield trace_message_header

        sample.each do |trace|

        end

        self
      end

    private

      def trace_message_header
        s = TRACE_MESSAGE_ID.dup
        append_uint64(s, sample.length)
      end

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

    end

    attr_reader :strings

    def initialize
      @strings = {}
    end

    def serialize(sample)
      Iterator.new(self, sample)
    end

  private

    def zomg
      # stuff
    end

  end
end
