module Tilde
  class Sample

    attr_reader :size, :count

    def initialize(size)
      @size   = size
      @values = []
      clear
    end

    def clear
      @values.clear
      @count = 0
    end

    def empty?
      @count == 0
    end

    def each
      i  = 0
      to = [@size, @count].min

      while i < to
        yield @values[i]
        i += 1
      end

      self
    end

    def <<(val)
      @count += 1

      if (count <= @size)
        @values[@count - 1] = val
      else
        r = rand(@count)
        @values[r] = val if r < @size
      end

      self
    end

  end
end
