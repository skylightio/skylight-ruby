require 'thread'

module Skylight
  module Util
    # Simple thread-safe queue backed by a ring buffer. Will only block when
    # poping. Single consumer only
    class Queue

      def initialize(max)
        unless max > 0
          raise ArgumentError, "queue size must be positive"
        end

        @max     = max
        @values  = [nil] * max
        @consume = 0
        @produce = 0
        @waiting = nil
        @mutex   = Mutex.new
      end

      def empty?
        @mutex.synchronize { __empty? }
      end

      def length
        @mutex.synchronize { __length }
      end

      # Returns the number of items in the queue or nil if the queue is full
      def push(obj)
        ret = nil

        @mutex.synchronize do
          return if __length == @max
          @values[@produce] = obj
          @produce = (@produce + 1) % @max

          ret = __length

          # Wakeup a blocked thread
          if t = @waiting
            t.run rescue nil
          end
        end

        ret
      end

      def pop(timeout = nil)
        if timeout && timeout < 0
          raise ArgumentError, "timeout must be nil or >= than 0"
        end

        @mutex.synchronize do
          if __empty?
            if !timeout || timeout > 0
              return if @waiting
              @waiting = Thread.current
              begin
                @mutex.sleep(timeout)
              ensure
                @waiting = nil
              end
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
