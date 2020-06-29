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
        while @data.size > @max_size
          @data.shift
        end
      end

      # Individual hash operations here are atomic in MRI.
      def fetch(key)
        found = true
        value = @data.delete(key) { found = false }

        if !found && block_given?
          value = yield
        end

        @data[key] = value if value

        if !found && value && @data.length > @max_size
          @data.shift
        end

        value
      end

      def clear
        @data.clear
      end
    end
  end
end
