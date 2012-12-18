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
        @config = config
        @interval = interval
        @from = from
        @to = from + interval
        @flush_at = @to + FLUSH_DELAY
        @sample = Util::UniformSample.new(config.samples_per_interval)
        @counts = Hash.new { |h,k| h[k] = 0 }
      end

      def should_flush?(now)
        now >= @flush_at
      end

      def next_batch
        Batch.new(@config, @to, @interval)
      end

      def empty?
        @sample.empty?
      end

      def wants?(trace)
        return trace.to >= @from && trace.to < @to
      end

      def push(trace)
        # Count it
        @counts[trace.endpoint] += 1
        # Push the trace into the sample
        @sample << trace
      end
    end

    attr_reader :instrumenter, :connection

    def initialize(instrumenter)
      @instrumenter = instrumenter
      @interval     = config.interval
      @protocol     = config.protocol

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
      return self unless @thread
      @queue.push(trace)
      self
    end

    def iter(msg, now=Util.clock.now)
      unless @current_batch
        interval = Util.clock.convert(@interval)
        from = (now / interval) * interval

        # If we're still accepting traces from the previous batch
        # Create the previous interval instead
        if now < from + FLUSH_DELAY
          from -= interval
        end

        @current_batch = Batch.new(config, from, interval)
        @next_batch    = @current_batch.next_batch
      end

      if msg == :SHUTDOWN
        flush(@current_batch) if @current_batch
        flush(@next_batch)    if @next_batch
        return false
      end

      while @current_batch && @current_batch.should_flush?(now)
        flush(@current_batch)
        @current_batch = @next_batch
        @next_batch = @current_batch.next_batch
      end

      if Trace === msg
        if @current_batch.wants?(msg)
          @current_batch.push(msg)
        elsif @next_batch.wants?(msg)
          @next_batch.push(msg)
        else
          # Seems bad bro
        end
      end

      true
    end

  private

    def config
      @instrumenter.config
    end

    def logger
      config.logger
    end

    def reset
      @queue = Util::Queue.new(config.max_pending_traces)
    end

    def work
      http_connect

      loop do
        msg = @queue.pop(@interval.to_f / 20)
        if msg
          success = iter(msg)
          return if !success
        end
      end
    rescue Exception => e
      logger.error [ :WORKER, e ]
      logger.error(e.backtrace)
    end

    attr_reader :sample_starts_at, :interval

    def flush(batch)
      return if batch.empty?

      body = ''
      # write the body
      @protocol.write(body, batch.from, batch.counts, batch.sample)

      logger.debug "~~~~~~~~~~~~~~~~ BODY SIZE ~~~~~~~~~~~~~~~~"
      logger.debug "  Before: #{body.bytesize}"

      if config.deflate?
        body = Util::Gzip.compress(body)
        logger.debug "  After:  #{body.bytesize}"
      end

      # send
      http_post(body)
    end

    def http_connect
      @http = Net::HTTP.new config.host, config.port
      @http.read_timeout = 60
    end

    def http_post(body)
      req = http_request(body.bytesize)
      req.body = body

      resp = @http.request req

      logger.debug "~~~~~~~~~~~~~~~~~ RESPONSE ~~~~~~~~~~~"
      logger.debug "Status: #{resp.code}"
      logger.debug "Headers:"
      resp.each_header do |key, val|
        logger.debug "  #{key}: #{val}"
      end
      logger.debug "BODY:"
      logger.debug resp.body
      logger.debug "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    end

    def http_request(length)
      hdrs = {}

      hdrs[CONTENT_LENGTH] = length.to_s
      hdrs[AUTHORIZATION]  = config.authentication_token
      hdrs[CONTENT_TYPE]   = APPLICATION_JSON

      if config.deflate?
        hdrs[CONTENT_ENCODING] = GZIP
      end

      Net::HTTPGenericRequest.new \
        'POST',   # Request method
        true,     # There is a request body
        true,     # There is a response body
        ENDPOINT, # Endpoint
        hdrs
    end

  end
end
