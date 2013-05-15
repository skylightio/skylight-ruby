require 'thread'

module Skylight
  module Util
    class Task

      def initialize(size, timeout = 0.1, &blk)
        @thread  = nil
        @queue   = Util::Queue.new(size)
        @lock    = Mutex.new
        @timeout = timeout
        @checks  = []
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

        ret = !!t.join(timeout)

        unless ret
          begin
            t.kill # FORCE KILL!!!
          rescue ThreadError
          end
        end

        @thread = nil

        ret
      end

    private

      def __spawn
        @lock.synchronize do
          return if spawned?

          @thread = Thread.new do
            unless work
              # TODO: Something went wrong :'(
            end
          end
        end
      end

      def work
        return unless q = @queue

        while true
          if msg = q.pop(@timeout)
            return true if msg == :SHUTDOWN

            unless tick(msg)
              return false
            end
          else
            # Handle lost :SHUTDOWN message
            return unless @queue
          end
        end

        true
      end

      def tick(msg)
        return true unless @blk
        begin
          @blk.call(msg)
        rescue Exception => e
          puts e.message
        end
      end

    end
  end
end
