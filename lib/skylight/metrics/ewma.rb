module Skylight
  module Metrics

    # An exponentially-weighted moving average. Not thread-safe
    class EWMA
      include Util::Conversions

      INTERVAL = 5

      # Some common EWMA
      attr_reader :interval

      def initialize(alpha, interval)
        @rate = 0.0
        @alpha = alpha
        @interval = secs_to_nanos(interval).to_f
        @uncounted = 0
        @initialized = false
      end

      def self.alpha(minutes, interval = INTERVAL)
        1 - Math.exp(-interval / 60.0 / minutes)
      end

      # Some common EWMA

      M1  = alpha(1)
      M5  = alpha(5)
      M15 = alpha(15)

      def self.one_minute_ewma
        EWMA.new M1, INTERVAL
      end

      def self.five_minute_ewma
        EWMA.new M5, INTERVAL
      end

      def self.fifteen_minute_ewma
        EWMA.new M15, INTERVAL
      end

      def update(count)
        @uncounted += count
      end

      def tick
        # Compute the rate this interval (aka the num of occurences this tick)
        instant_rate = @uncounted / @interval

        # Reset the count
        @uncounted = 0

        if @initialized
          @rate += (@alpha * (instant_rate - @rate))
        else
          @rate = instant_rate
          @initialized = true
        end
      end

      # Get the rate in the requested interval (where the interval is specified
      # in number of seconds
      def rate(interval = 1)
        @rate * secs_to_nanos(interval)
      end
    end
  end
end
