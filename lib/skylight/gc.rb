require 'thread'

module Skylight
  class GC
    METHODS = [ :enable, :total_time ]
    TH_KEY  = :SK_GC_CURR_WINDOW

    include Util::Logging

    def self.update
      if win = Thread.current[TH_KEY]
        win.update
      end
    end

    def self.time
      if win = Thread.current[TH_KEY]
        win.time
      else
        0.0
      end
    end

    attr_reader :config

    def initialize(config, profiler)
      @listeners = []
      @config    = config
      @lock      = Mutex.new
      @time      = 0.0

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

    def start_track
      return if Thread.current[TH_KEY]

      unless @profiler
        win = Window.new(nil)
      else
        win = Window.new(self)

        @lock.synchronize do
          __update
          @listeners << win
        end
      end

      Thread.current[TH_KEY] = win
    end

    def stop_track
      if win = Thread.current[TH_KEY]
        Thread.current[TH_KEY] = nil
        win.release
      end
    end

    def track
      return unless block_given?

      start_track

      begin
        yield
      ensure
        stop_track
      end
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

      if diff > 0.0
        @listeners.each do |l|
          l.add(diff)
        end
      end
    end

    class Window
      attr_reader :time

      def initialize(global)
        @global = global
        @time   = 0.0
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
