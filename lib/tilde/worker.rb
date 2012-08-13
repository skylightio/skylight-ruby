module Tilde
  class Worker
    MAX_PENDING = 1_000

    def self.start
      new.start
    end

    def start
      shutdown if @thread

      @queue  = Queue.new
      @thread = Thread.new { work }

      self
    end

    def shutdown
      # Don't do anything if the worker isn't running
      return self unless @thread

      @queue << :SHUTDOWN

      unless @thread.join(0.5)
        @thread.kill
      end

      @thread = nil

      self
    end

    def submit(trace)
      return unless @thread
      return if @queue.length >= MAX_PENDING

      @queue << trace
    end

  private

    def work
      loop do
        msg = @queue.pop

        if msg == :SHUTDOWN
          return
        end
      end
    rescue Exception => e
      # TODO: Restart the worker
    end

  end
end
