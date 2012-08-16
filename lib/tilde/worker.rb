module Tilde
  class Worker
    attr_reader :instrumenter, :connection

    def initialize(instrumenter)
      @instrumenter = instrumenter
      @sample       = Util::UniformSample.new(config.samples_per_interval)
      @interval     = config.interval
      # @serializer = Serializer.new

      reset
    end

    def start!
      shutdown! if @thread

      # @connection = Connection.open(@config.host, @config.port, @config.ssl?)
      @thread = Thread.new { work }

      self
    end

    def shutdown!
      # Don't do anything if the worker isn't running
      return self unless @thread

      thread  = @thread
      @thread = nil

      @queue.push(:SHUTDOWN)

      unless thread.join(1)
        begin
          # FORCE KILL!!
          thread.kill
        rescue ThreadError
        end
      end

      reset
      self
    end

    def submit(trace)
      return unless @thread
      @queue.push(trace)
      self
    end

  private

    def config
      @instrumenter.config
    end

    def reset
      @queue = Util::Queue.new(config.max_pending_traces)
      @sample_starts_at = Time.at(0)
      @sample.clear
    end

    def work
      loop do
        msg = @queue.pop(@interval.to_f / 20)

        if msg == :SHUTDOWN
          flush
          return
        end

        now = Time.now

        if now >= flush_at
          flush
          tick(now)
          @flush_at = next_flush_at(now)
        end

        if Trace === msg
          # Push the message into the sample
          @sample << msg
        end
      end
    rescue Exception => e
      p [ :WORKER, e ]
      puts e.backtrace
    end

    def flush_at
      @sample_starts_at + @interval
    end

    def tick(now)
      @sample_starts_at = Time.at(@interval * (now.to_i / @interval))
    end

    def flush
      return if @sample.empty?

      @sample.each do |v|
        p [ :ENDPOINT, v.endpoint ]
      end

      @sample.clear
    end

  end
end
