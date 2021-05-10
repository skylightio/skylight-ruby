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
        @data.shift while @data.size > @max_size
      end

      # Individual hash operations here are atomic in MRI.
      def fetch(key)
        found = true
        value = @data.delete(key) { found = false }

        value = yield if !found && block_given?

        @data[key] = value if value

        @data.shift if !found && value && @data.length > @max_size

        value
      end

      def clear
        @data.clear
      end
    end
  end
end
