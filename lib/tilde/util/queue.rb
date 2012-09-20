require 'thread'

module Tilde
  module Util
    # Blocking sized queue implemented as a ring buffer
    class Queue

      def initialize(max)
        unless max > 0
          raise ArgumentError, "queue size must be positive"
        end

        @max     = max
        @values  = [nil] * max
        @consume = 0
        @produce = 0
        @waiting = []
        @mutex   = Mutex.new
      end

      def empty?
        @mutex.synchronize { __empty? }
      end

      def length
        @mutex.synchronize { __length }
      end

      # Returns true if the item was queued, false otherwise
      def push(obj)
        @mutex.synchronize do
          return false if __length == @max
          @values[@produce] = obj
          @produce = (@produce + 1) % @max

          # Wakeup a blocked thread
          begin
            t = @waiting.shift
            t.wakeup if t
          rescue ThreadError
            retry
          end
        end

        true
      end

      def pop(timeout = nil)
        if timeout && timeout < 0
          raise ArgumentError, "timeout must be nil or >= than 0"
        end

        @mutex.synchronize do
          if __empty?
            if !timeout || timeout > 0
              t = Thread.current
              @waiting << t
              @mutex.sleep(timeout)
              # Ensure that the thread is not in the waiting list
              @waiting.delete(t)
            else
              return
            end
          end

          __pop unless __empty?
        end
      end

    private

      def __length
        ((@produce - @consume) % @max)
      end

      def __empty?
        @produce == @consume
      end

      def __pop
        i = @consume
        v = @values[i]

        @values[i] = nil
        @consume = (i + 1) % @max

        return v
      end

    end
  end
end
