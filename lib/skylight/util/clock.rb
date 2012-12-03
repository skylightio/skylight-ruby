module Skylight
  module Util
    class Clock
      MICROSEC_PER_SEC = 1.to_f / 1_000_000

      # Resolution is in seconds
      def initialize(resolution)
        @resolution = resolution
        @usec_mult  = MICROSEC_PER_SEC / resolution
      end

      def now
        now  = Time.now
        sec  = now.to_i / @resolution
        usec = now.usec * @usec_mult
        (sec + usec).floor
      end
    end

    @clock = Clock.new(0.0001)

    def self.clock
      @clock
    end
  end
end
