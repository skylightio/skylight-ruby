# Based on code by Sam Saffron: https://stackoverflow.com/a/16161783/181916
module Skylight
  module Util
    class LruCache
      def initialize(max_size)
        @max_size = max_size
        @data = {}
      end

      def max_size=(size)
        raise ArgumentError, :max_size if @max_size < 1

        @max_size = size
        if @max_size < @data.size
          @data.keys[0..(@max_size - @data.size)].each do |k|
            @data.delete(k)
          end
        end
      end

      def [](key)
        found = true
        value = @data.delete(key) { found = false }
        if found
          @data[key] = value
        end
      end

      def []=(key, val)
        @data.delete(key)
        @data[key] = val
        if @data.length > @max_size
          @data.delete(@data.first[0])
        end
      end

      def each
        @data.reverse.each do |pair|
          yield pair
        end
      end

      def to_a
        @data.to_a.reverse
      end

      def delete(key)
        @data.delete(key)
      end

      def clear
        @data.clear
      end

      def count
        @data.count
      end

      def key?(key)
        @data.key?(key)
      end
    end
  end
end
