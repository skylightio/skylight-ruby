module Skylight
  module Util
    # Helpers to reduce memory allocation
    module AllocationFree
      # Find an item in an array without allocation.
      #
      # @param array [Array] the array to search
      # @yield a block called against each item until a match is found
      # @yieldparam item an item from the array
      # @yieldreturn [Boolean] whether `item` matches the criteria
      # return the found item or nil, if nothing found
      def array_find(array)
        i = 0

        while i < array.size
          item = array[i]
          return item if yield item

          i += 1
        end

        nil
      end
    end
  end
end
