require 'thread'

module Skylight
  class GC
    METHODS = [ :enable, :total_time ]
    TH_KEY  = :SK_GC_CURR_WINDOW

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

    def initialize(profiler)
      @listeners = []
      @lock      = Mutex.new

      if METHODS.all? { |m| profiler.respond_to?(m) }
        @profiler = profiler
      end
    end

    def start_track
      return if Thread.current[TH_KEY]

      unless @profiler
        win = Window.new(nil)
      else
        win = Window.new(self)

        @lock.synchronize do
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
        time = @profiler.total_time

        if time > 0
          @profiler.clear
          @listeners.each do |l|
            l.add(time)
          end
        end
      end

      nil
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
