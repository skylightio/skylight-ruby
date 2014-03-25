require 'thread'

module Skylight
  module Metrics
    class Meter
      def initialize(ewma = EWMA.one_minute_ewma, clock = Util::Clock.default)
        @ewma = ewma
        @lock = Mutex.new
        @clock = clock
        @start_time = @clock.tick
        @last_tick = @start_time
      end

      def mark(n = 1)
        @lock.synchronize do
          tick_if_necessary
          @ewma.update(n)
        end
      end

      def rate
        @lock.synchronize do
          tick_if_necessary
          @ewma.rate(1)
        end
      end

      def call
        rate
      end

    private

      def tick_if_necessary
        old_tick = @last_tick
        new_tick = @clock.tick

        # How far behind are we
        age = new_tick - old_tick

        if age >= @ewma.interval
          new_tick = new_tick - age % @ewma.interval

          # Update the last seen tick
          @last_tick = new_tick

          # Number of missing ticks
          required_ticks = age / @ewma.interval

          while required_ticks > 0
            @ewma.tick
            required_ticks -= 1
          end
        end
      end
    end
  end
end
