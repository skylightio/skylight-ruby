module Skylight
  module Util
    class AtomicRef
      def initialize(v = nil)
        @v = v
        @m = Mutex.new
      end

      def get
        @m.synchronize { @v }
      end

      def set(v)
        @m.synchronize { @v = v }
      end

      def compare_and_set(expect, v)
        @m.synchronize do
          return false unless @v == expect
          @v = v
        end

        true
      end

      def get_and_set(v)
        while true
          c = get
          return c if compare_and_set(c, v)
        end
      end
    end

    class AtomicInteger < AtomicRef

      def initialize(v = 0)
        super(v)
      end

      def add_and_get(delta)
        while true
          c = get
          n = c + delta
          return n if compare_and_set(c, n)
        end
      end

      def increment_and_get
        add_and_get(1)
      end

      def decrement_and_get
        add_and_get(-1)
      end

      def get_and_add(delta)
        while true
          c = get
          n = c + delta
          return c if compare_and_set(c, n)
        end
      end

      def get_and_increment
        get_and_add(1)
      end

      def get_and_decrement
        get_and_add(-1)
      end
    end
  end
end
