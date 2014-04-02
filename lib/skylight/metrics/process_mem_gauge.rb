module Skylight
  module Metrics
    class ProcessMemGauge

      def initialize(cache_for = 30, clock = Util::Clock.default)
        @value = nil
        @cache_for = cache_for
        @last_check_at = 0
        @clock = clock
      end

      def call(now = @clock.absolute_secs)
        if !@value || should_check?(now)
          @value = check
          @last_check_at = now
        end

        @value
      end

    private

      def check
        `ps -o rss= -p #{Process.pid}`.to_i / 1024
      rescue Errno::ENOENT, Errno::EINTR
        0
      end

      def should_check?(now)
        now >= @last_check_at + @cache_for
      end
    end
  end
end
