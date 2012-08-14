module Tilde
  class Worker
    MAX_PENDING = 1_000
    SAMPLE_SIZE = 100
    INTERVAL    = 5

    def self.start
      new.start
    end

    def initialize
      @sample = Sample.new(SAMPLE_SIZE)
      @flush_at = Time.at(0)
    end

    def start
      shutdown if @thread

      @queue  = Queue.new(MAX_PENDING)
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
      @queue.push trace
    end

  private

    def work
      loop do
        msg = @queue.pop(INTERVAL)
        now = Time.now

        if msg == :SHUTDOWN
          flush
          return
        end

        if now >= @flush_at
          flush
          @flush_at = next_flush_at(now)
        end

        # Push the message into the sample
        @sample << msg if msg
      end
    rescue Exception => e
      p [ :WORKER, e ]
      puts e.backtrace
    end

    def flush
      return if @sample.empty?

      @sample.each do |v|
        # p [ v.from, v.spans.length ]
      end

      @sample.clear
    end

    def next_flush_at(now)
      Time.at(INTERVAL * (now.to_i / INTERVAL + 1))
    end

  end
end
