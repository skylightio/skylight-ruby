module Skylight
  module Util
    class Clock

      def micros
        n = Time.now
        n.to_i * 1_000_000 + n.usec
      end

      def secs
        micros / 1_000_000
      end

      def self.micros
        default.micros
      end

      def self.secs
        default.secs
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
