module Skylight
  module Beefcake
    class Buffer
      MinUint32 =  0
      MaxUint32 =  (1<<32)-1
      MinInt32  = -(1<<31)
      MaxInt32  =  (1<<31)-1

      MinUint64 =  0
      MaxUint64 =  (1<<64)-1
      MinInt64  = -(1<<63)
      MaxInt64  =  (1<<63)-1

      MaxFixnum =  (1 << (1.size * 8 - 2) - 1)

      def self.wire_for(type)
        case type
        when Class
          if encodable?(type)
            2
          else
            raise UnknownType, type
          end
        when :int32, :uint32, :sint32, :int64, :uint64, :sint64, :bool, Module
          0
        when :fixed64, :sfixed64, :double
          1
        when :string, :bytes
          2
        when :fixed32, :sfixed32, :float
          5
        else
          raise UnknownType, type
        end
      end

      def self.encodable?(type)
        return false if ! type.is_a?(Class)
        type < Message
      end

      attr_accessor :buf

      alias :to_s   :buf
      alias :to_str :buf

      class OutOfRangeError < StandardError
        def initialize(n)
          super("Value of of range: %d" % [n])
        end
      end

      class BufferOverflowError < StandardError
        def initialize(s)
          super("Too many bytes read for %s" % [s])
        end
      end

      class UnknownType < StandardError
        def initialize(s)
          super("Unknown type '%s'" % [s])
        end
      end

      def initialize(buf="")
        unless String === buf
          raise ArgumentError, "buf must be a string"
        end

        self.buf = buf
      end

      if ''.respond_to?(:force_encoding)
        def buf=(buf)
          @buf = buf.force_encoding(BINARY)
        end
      end

      def length
        @buf.respond_to?(:bytesize) ? @buf.bytesize : @buf.length
      end

      BINARY = 'BINARY'.freeze

      # Detect a ruby encodings bug, as far as I know, this exists in
      # most versions fo JRuby as well as 1.9.2
      def self.current_ruby_has_encoding_bug?
        base = "\0\1".force_encoding('BINARY')
        base << "BUG".encode("UTF-8")
        base.encoding.to_s == 'UTF-8'
      end

      if ''.respond_to?(:force_encoding) && current_ruby_has_encoding_bug?
        def <<(bytes)
          buf << bytes
          buf.force_encoding(BINARY)
          buf
        end
      else
        def <<(bytes)
          buf << bytes
        end
      end

      def read(n)
        case n
        when Class
          n.decode(read_string)
        when Symbol
          __send__("read_#{n}")
        when Module
          read_uint64
        else
          buf.slice!(0, n)
        end
      end
    end
  end
end
