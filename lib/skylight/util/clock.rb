module Skylight
  module Util
    class Clock

      def absolute_secs
        Time.now.to_i
      end

      if Skylight.native?
        def nanos
          native_hrtime
        end
      else
        # Implement nanos to work when native extension is not present
        def nanos
          now = Time.now
          now.to_i * 1_000_000_000 + now.usec * 1_000
        end
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
