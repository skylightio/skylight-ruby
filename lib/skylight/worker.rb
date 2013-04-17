module Skylight
  class Worker
    CONTENT_ENCODING = 'content-encoding'.freeze
    CONTENT_LENGTH   = 'content-length'.freeze
    CONTENT_TYPE     = 'content-type'.freeze
    APPLICATION_JSON = 'application/json'.freeze
    DIREWOLF_REPORT  = 'application/x-direwolf-report'.freeze
    AUTHORIZATION    = 'authorization'.freeze
    ENDPOINT         = '/report'.freeze
    DEFLATE          = 'deflate'.freeze
    GZIP             = 'gzip'.freeze
    FLUSH_DELAY      = Util.clock.convert(0.5)

    class Batch
      attr_reader :from, :counts, :sample

      def initialize(config, from, interval)
        @from     = from
        @flush_at = from + interval + FLUSH_DELAY
        @sample   = Util::UniformSample.new(config.samples_per_interval)
        @counts   = Hash.new(0)
      end

      def should_flush?(now)
        now >= @flush_at
      end

      def empty?
        @sample.empty?
      end

      def push(trace)
        # Count it
        @counts[trace.endpoint] += 1
        # Push the trace into the sample
        @sample << trace
      end
    end

    attr_reader :instrumenter, :connection, :config

    def initialize(instrumenter)
      @instrumenter = instrumenter
      @config       = instrumenter.config
      @interval     = config.interval
      @protocol     = config.protocol

      reset
    end

    def start!
      shutdown! if @thread
      @thread = Thread.new { work }
      self
    end

    def shutdown!
      # Don't do anything if the worker isn't running
      return self unless @thread

      thread  = @thread
      @thread = nil

      @queue.push(:SHUTDOWN)

      unless thread.join(5)
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
    end

    # A worker iteration
    def iter(msg, now=Util.clock.now)
      interval = Util.clock.convert(@interval)

      @current_batch ||= Batch.new(config, start(now, interval), interval)

      if msg == :SHUTDOWN
        flush(@current_batch) if @current_batch
        @current_batch = nil
        return false
      end

      if @current_batch.should_flush?(now)
        flush(@current_batch)
        @current_batch = Batch.new(config, start(now, interval), interval)
      end

      return true if msg.nil?

      if Trace === msg
        debug "Received trace"
        @current_batch.push(msg)
      else
        debug "Received something other than a trace: #{msg.inspect}"
      end

      true
    end

  private

    def start(now, interval)
      (now / interval) * interval
    end

    def logger
      config.logger
    end

    def reset
      @queue = Util::Queue.new(config.max_pending_traces)
    end

    def work
      loop do
        msg = @queue.pop(@interval.to_f / 20)
        success = iter(msg)
        return if !success
      end
    rescue Exception => e
      logger.error "[SKYLIGHT] #{e.message} - #{e.class} - #{e.backtrace.first}"
      if logger.debug?
        logger.debug(e.backtrace.join("\n"))
      end
    end

    attr_reader :sample_starts_at, :interval

    def flush(batch)
      return if batch.empty?
      # Skip if there is no authentication token
      return unless config.authentication_token

      debug "Flushing: #{batch}"

      body = ''
      # write the body
      @protocol.write(body, batch.from, batch.counts, batch.sample)

      @config.http.post(ENDPOINT, body)
    end

    def debug(msg)
      return unless logger && logger.debug?
      logger.debug "[SKYLIGHT] #{msg}"
    end

  end
end
