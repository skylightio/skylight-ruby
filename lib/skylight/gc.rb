require 'thread'

module Skylight
  # @api private
  class GC
    METHODS   = [ :enable, :total_time ]
    TH_KEY    = :SK_GC_CURR_WINDOW
    MAX_COUNT = 1000
    MAX_TIME  = 30_000_000

    include Util::Logging

    attr_reader :config

    def initialize(config, profiler)
      @listeners = []
      @config    = config
      @lock      = Mutex.new
      @time      = 0

      if METHODS.all? { |m| profiler.respond_to?(m) }
        @profiler = profiler
        @time = @profiler.total_time
      else
        debug "disabling GC profiling"
      end
    end

    def enable
      @profiler.enable if @profiler
    end

    def track
      unless @profiler
        win = Window.new(nil)
      else
        win = Window.new(self)

        @lock.synchronize do
          __update
          @listeners << win

          # Cleanup any listeners that might have leaked
          until @listeners[0].time < MAX_TIME
            @listeners.shift
          end

          if @listeners.length > MAX_COUNT
            @listeners.shift
          end
        end
      end

      win
    end

    def release(win)
      @lock.synchronize do
        @listeners.delete(win)
      end
    end

    def update
      @lock.synchronize do
        __update
      end

      nil
    end

  private

    def __update
      time  = @profiler.total_time
      diff  = time - @time
      @time = time

      if diff > 0
        @listeners.each do |l|
          l.add(diff)
        end
      end
    end

    class Window
      attr_reader :time

      def initialize(global)
        @global = global
        @time   = 0
      end

      def update
        @global.update if @global
      end

      def add(time)
        @time += time
      end

      def release
        @global.release(self) if @global
      end
    end

  end
end
