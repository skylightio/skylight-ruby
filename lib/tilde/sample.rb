module Tilde
  class Sample

    attr_reader :from, :size, :count

    def initialize(from, size)
      @size     = size
      @values   = []
      @pending  = 0
      @from     = from
    end

    def length
      @size < @count ? @size : @count
    end

    def empty?
      @count == 0
    end

    def each
      i  = 0
      to = @size < @count ? @size : @count

      while i < to
        v = @values[i]

        unless Slot === v
          yield v
        end

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

    class Slot < Struct.new(:sample, :index)
      def commit(val)
        sample.commit(self, val)
      end
    end

    def reserve
      if idx = increment!
        slot = Slot.new(self, idx)

        unless Slot === @values[idx]
          @pending += 1
        end

        @values[idx] = slot
      end
    end

    def commit(slot, val)
      if slot == @values[slot.index]
        @values[slot.index] = val
        @pending -= 1
      end

      self
    end

    def completed?
      @pending == 0
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
