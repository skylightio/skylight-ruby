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

      def shutdown(timeout = nil)
        t = nil
        @lock.synchronize do
          t = @thread
          @queue = nil
        end

        return true if timeout && timeout < 0
        return true unless t

        !!t.join(timeout)
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
        while q = @queue
          if msg = q.pop(@timeout)
            unless tick(msg)
              return false
            end
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
