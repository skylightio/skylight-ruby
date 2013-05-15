require 'thread'

module Skylight
  module Util
    class Task

      def initialize(size, timeout = 0.1, &blk)
        @thread  = nil
        @queue   = Util::Queue.new(size)
        @lock    = Mutex.new
        @timeout = timeout
        @blk     = blk
      end

      def submit(msg)
        return unless q = @queue

        spawn

        !!q.push(msg)
      end

      def spawn
        unless spawned?
          __spawn
        end
      end

      def spawned?
        !!@thread
      end

      def running?
        spawned? && !!@queue
      end

      def shutdown(timeout = 5)
        t = nil
        m = false

        @lock.synchronize do
          t = @thread

          if q = @queue
            m = true
            q.push(:SHUTDOWN)
            @queue = nil
          end
        end

        return true if timeout && timeout < 0
        return true unless t

        ret = nil

        begin
          ret = !!t.join(timeout)
        ensure
          if !ret && m
            begin
              t.kill # FORCE KILL!!!
            rescue ThreadError
            end
          end
        end

        ret
      end

    private

      def __spawn
        @lock.synchronize do
          return if spawned?

          @thread = Thread.new do
            unless work
              @queue = nil
            end
          end
        end
      end

      def work
        return unless q = @queue

        while true
          if msg = q.pop(@timeout)
            return true if msg == :SHUTDOWN

            unless handle(msg)
              return false
            end
          else
            # Handle lost :SHUTDOWN message
            return unless @queue
            # just a tick
            begin
              unless handle(nil)
                return false
              end
            rescue Exception => e
              puts e.message
              sleep 1 # Throttle
            end
          end
        end

        true
      end

      def handle(msg)
        return true unless @blk
        @blk.call(msg)
      end

    end
  end
end
