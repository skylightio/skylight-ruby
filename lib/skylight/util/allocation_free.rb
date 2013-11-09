module Skylight
  module AllocationFree
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
