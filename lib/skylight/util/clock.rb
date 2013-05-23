module Skylight
  module Util
    class Clock

      def now
        n = Time.now
        n.to_i + n.usec.to_f / 1_000_000
      end

      def self.now
        default.now
      end

      def self.default
        @clock ||= Clock.new
      end

      def self.default=(clock)
        @clock = clock
      end

    end
  end
end
