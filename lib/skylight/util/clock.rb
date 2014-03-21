module Skylight
  module Util
    class Clock

      if Skylight.native?
        def tick
          native_hrtime
        end
      else
        def tick
          now = Time.now
          now.to_i * 1_000_000_000 + now.usec * 1_000
        end
      end

      # TODO: rename to secs
      def absolute_secs
        Time.now.to_i
      end

      # TODO: remove
      def nanos
        tick
      end

      # TODO: remove
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
