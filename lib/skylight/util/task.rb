require 'thread'

module Skylight
  module Util
    class Task
      SHUTDOWN = :__SK_TASK_SHUTDOWN

      include Util::Logging

      def initialize(size, timeout = 0.1, &blk)
        @pid     = Process.pid
        @thread  = nil
        @size    = size
        @lock    = Mutex.new
        @timeout = timeout
        @blk     = blk
      end

      def submit(msg, pid = Process.pid)
        return unless @pid

        spawn(pid)

        return unless q = @queue

        !!q.push(msg)
      end

      def spawn(pid = Process.pid)
        unless spawned?
          __spawn(pid)
        end

        true
      end

      def spawned?
        !!@thread
      end

      def running?
        spawned? && @pid
      end

      def shutdown(timeout = 5)
        t = nil
        m = false

        @lock.synchronize do
          t = @thread

          if q = @queue
            m = true
            q.push(SHUTDOWN)
            @pid = nil
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

      def __spawn(pid)
        @lock.synchronize do
          return if spawned? && @pid == pid
          @pid    = Process.pid
          @queue  = Util::Queue.new(@size)
          @thread = Thread.new do
            begin
              unless work
                @queue = nil
              end

              t { "shutting down task" }
              finish
            rescue Exception => e
              error "failed to execute task; msg=%s", e.message
              t { e.backtrace.join("\n") }
            end
          end
        end

        true
      end

      def work
        return unless q = @queue

        while @pid
          if msg = q.pop(@timeout)
            return true if SHUTDOWN == msg

            unless __handle(msg)
              return false
            end
          else
            return unless @queue
            # just a tick
            unless __handle(msg)
              return false
            end
          end
        end

        # Drain the queue
        while msg = q.pop(0)
          return true if SHUTDOWN == msg

          unless __handle(msg)
            return false
          end
        end

        true
      end

      def __handle(msg)
        begin
          handle(msg)
        rescue Exception => e
          error "error handling event; msg=%s; event=%p", e.message, msg
          t { e.backtrace.join("\n") }
          sleep 1
          true
        end
      end

      def handle(msg)
        return true unless @blk
        @blk.call(msg)
      end

      def finish
      end

    end
  end
end
