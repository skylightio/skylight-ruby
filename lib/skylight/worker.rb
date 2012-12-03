module Skylight
  class Worker
    CONTENT_ENCODING = 'content-encoding'.freeze
    CONTENT_LENGTH   = 'content-length'.freeze
    CONTENT_TYPE     = 'content-type'.freeze
    DIREWOLF_REPORT  = 'application/x-direwolf-report'.freeze
    AUTHENTICATION   = 'authentication'.freeze
    ENDPOINT         = '/agent/report'.freeze
    DEFLATE          = 'deflate'.freeze

    attr_reader :instrumenter, :connection

    def initialize(instrumenter)
      @instrumenter = instrumenter
      @sample       = Util::UniformSample.new(config.samples_per_interval)
      @interval     = config.interval
      @protocol     = Proto.new

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

    def reset_counts
      @counts = Hash.new { |h,k| h[k] = 0 }
    end

    def work
      reset_counts
      http_connect

      loop do
        next unless msg = @queue.pop(@interval.to_f / 20)

        if msg == :SHUTDOWN
          flush
          return
        end

        now = Time.now

        if now >= flush_at
          flush
          tick(now)
        end

        if Trace === msg
          if msg.from >= sample_ends_at.to_i * 10_000
            flush
            tick(now)
          end

          # Count it
          @counts[msg.endpoint] += 1
          # Push the message into the sample
          @sample << msg
        end
      end
    rescue Exception => e
      p [ :WORKER, e ]
      puts e.backtrace
    end

    attr_reader :sample_starts_at, :interval

    def sample_ends_at
      sample_starts_at + interval
    end

    # Add a delay to (hopefully) account for threading delays
    def flush_at
      sample_ends_at + 0.5
    end

    def tick(now)
      @sample_starts_at = Time.at(@interval * (now.to_i / @interval))
    end

    def flush
      return if @sample.empty?

      body = ''
      # write the body
      @protocol.write(body, @counts, @sample)

      puts "~~~~~~~~~~~~~~~~ BODY SIZE ~~~~~~~~~~~~~~~~"
      puts "  Before: #{body.bytesize}"

      if config.deflate?
        body = Zlib::Deflate.deflate(body)
        puts "  After:  #{body.bytesize}"
      end

      # send
      http_post(body)

      @sample.clear
      reset_counts
    end

    def http_connect
      @http = Net::HTTP.new config.host, config.port
      @http.read_timeout = 60
    end

    def http_post(body)
      req = http_request(body.bytesize)
      req.body = body

      resp = @http.request req

      puts "~~~~~~~~~~~~~~~~~ RESPONSE ~~~~~~~~~~~"
      puts "Status: #{resp.code}"
      puts "Headers:"
      resp.each_header do |key, val|
        puts "  #{key}: #{val}"
      end
    end

    def http_request(length)
      hdrs = {}

      hdrs[CONTENT_LENGTH] = length.to_s
      hdrs[AUTHENTICATION]  = config.authentication_token
      hdrs[CONTENT_TYPE]   = DIREWOLF_REPORT

      if config.deflate?
        hdrs[CONTENT_ENCODING] = DEFLATE
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
