module Tilde
  class Worker
    MAX_PENDING = 1_000
    SAMPLE_SIZE = 100
    INTERVAL    = 5

    attr_reader :instrumenter, :connection

    def initialize(instrumenter)
      @instrumenter = instrumenter
      @runnable = true
      # @serializer = Serializer.new
      # @flush_at = Time.at(0)
    end

    def start
      shutdown if @thread

      # @connection = Connection.open(@config.host, @config.port, @config.ssl?)
      @thread = Thread.new { work }

      self
    end

    def shutdown
      # Don't do anything if the worker isn't running
      return self unless @thread

      synchronize do
        @runnable = false

        begin
          @thread.wakeup
        rescue ThreadError
        end
      end

      unless @thread.join(1)
        # FORCE KILL!!
        @thread.kill
      end

      @thread = nil

      self
    end

  private

    def synchronize
      @instrumenter.synchronize { yield }
    end

    def runnable?
      synchronize { @runnable }
    end

    def work
      loop do
        return unless runnable?

        sleep 0.1

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
        p [ :ENDPOINT, v.endpoint ]
      end

      @sample.clear
    end

    def next_flush_at(now)
      Time.at(INTERVAL * (now.to_i / INTERVAL + 1))
    end

  end
end
