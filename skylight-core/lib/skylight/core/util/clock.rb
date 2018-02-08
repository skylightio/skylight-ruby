module Skylight::Core
  module Util
    # A more precise clock
    class Clock

      def self.use_native!
        class_eval do
          def tick
            native_hrtime
          end
        end
      end

      def tick
        now = Time.now
        now.to_i * 1_000_000_000 + now.usec * 1_000
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
