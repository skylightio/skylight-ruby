module Skylight
  module Util
    class Clock

      def absolute_secs
        Time.now.to_i
      end

      def nanos
        native_hrtime
      end

      def secs
        nanos / 1_000_000_000
      end

      def self.absolute_secs
        default.absolute_secs
      end

      def self.nanos
        default.nanos
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
