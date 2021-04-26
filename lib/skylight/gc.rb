require "skylight/util/logging"

module Skylight
  # @api private
  class GC
    METHODS = %i[enable total_time].freeze
    TH_KEY = :SK_GC_CURR_WINDOW
    MAX_COUNT = 1000
    MAX_TIME = 30_000_000

    include Util::Logging

    attr_reader :config

    def initialize(config, profiler)
      @listeners = []
      @config = config
      @lock = Mutex.new
      @time = 0

      if METHODS.all? { |m| profiler.respond_to?(m) }
        @profiler = profiler
        @time = @profiler.total_time
      else
        debug "disabling GC profiling"
      end
    end

    def enable
      @profiler&.enable
    end

    # Total time in microseconds for GC over entire process lifetime
    def total_time
      @profiler ? @profiler.total_time : nil
    end

    def track
      if @profiler
        win = Window.new(self)

        @lock.synchronize do
          __update
          @listeners << win

          # Cleanup any listeners that might have leaked
          @listeners.shift until @listeners[0].time < MAX_TIME

          @listeners.shift if @listeners.length > MAX_COUNT
        end

        win
      else
        Window.new(nil)
      end
    end

    def release(win)
      @lock.synchronize { @listeners.delete(win) }
    end

    def update
      @lock.synchronize { __update }

      nil
    end

    private

    def __update
      time = @profiler.total_time
      diff = time - @time
      @time = time

      @listeners.each { |l| l.add(diff) } if diff > 0
    end

    class Window
      attr_reader :time

      def initialize(global)
        @global = global
        @time = 0
      end

      def update
        @global&.update
      end

      def add(time)
        @time += time
      end

      def release
        @global&.release(self)
      end
    end
  end
end
