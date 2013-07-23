module Skylight
  module Util
    class UniformSample
      include Enumerable

      attr_reader :size, :count

      def initialize(size)
        @size   = size
        @count  = 0
        @values = []
      end

      def clear
        @count = 0
        @values.clear
        self
      end

      def length
        @size < @count ? @size : @count
      end

      def empty?
        @count == 0
      end

      def each
        i  = 0
        to = length

        while i < to
          yield @values[i]
          i += 1
        end

        self
      end

      def <<(v)
        if idx = increment!
          @values[idx] = v
        end

        self
      end

    private

      def increment!
        c = (@count += 1)

        if (c <= @size)
          c - 1
        else
          r = rand(@count)
          r if r < @size
        end
      end

    end
  end
end
