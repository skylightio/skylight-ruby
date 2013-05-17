require 'thread'

module Skylight
  module Util
    class Task
      SHUTDOWN = :__SK_TASK_SHUTDOWN

      def initialize(size, timeout = 0.1, &blk)
        @thread  = nil
        @queue   = Util::Queue.new(size)
        @lock    = Mutex.new
        @timeout = timeout
        @run     = true
        @blk     = blk
      end

      def submit(msg)
        return unless @run
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
        spawned? && @run
      end

      def shutdown(timeout = 5)
        t = nil
        m = false

        @lock.synchronize do
          t = @thread

          if q = @queue
            m = true
            q.push(SHUTDOWN)
            @run = false
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

        while @run
          if msg = q.pop(@timeout)
            return true if SHUTDOWN == msg

            unless handle(msg)
              return false
            end
          else
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

        # Drain the queue
        while msg = q.pop(0)
          return true if SHUTDOWN == msg

          unless handle(msg)
            return false
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
