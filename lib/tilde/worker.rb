module Tilde
  class Worker
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

    def work
      http_connect

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

      body = ''
      # write the body
      @protocol.write(body, @sample)

      puts "~~~~~~~~~~~~~~~~ BODY SIZE ~~~~~~~~~~~~~~~~"
      puts "  Before: #{body.bytesize}"
      # compress
      body = Zlib::Deflate.deflate(body)
      puts "  After:  #{body.bytesize}"
      # send
      http_post(body)

      @sample.clear
    end

    def http_connect
      @http = Net::HTTP.new 'localhost', 3001
      @http.read_timeout = 60
    end

    def http_post(body)
      req = http_request
      req.body = body

      resp = @http.request req

      puts "~~~~~~~~~~~~~~~~~ RESPONSE ~~~~~~~~~~~"
      puts "Status: #{resp.code}"
      puts "Headers:"
      resp.each_header do |key, val|
        puts "  #{key}: #{val}"
      end
    end

    def http_request
      Net::HTTPGenericRequest.new \
        'POST',  # Request method
        true,    # There is a request body
        true,    # There is a response body
        "/zomg", # Endpoint
        {}
    end

  end
end
