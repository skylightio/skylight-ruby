module Skylight
  module Util
    class EWMA

      attr_reader :rate

      def initialize(alpha)
        @alpha     = alpha
        @uncounted = AtomicInteger.new
        @rate      = nil
      end

      def update(n)
        @uncounted.add_and_get(n)
      end

      # Mark the passage of time and decay the current rate accordingly.
      # This method is obviously not thread-safe as is expected to be
      # invoked once every interval
      def tick()
        count = @uncounted.get_and_set(0)
        instantRate = count

        if rate
          rate += (alpha * (instantRate - rate))
        else
          rate = instantRate
        end
      end
    end
  end
end
