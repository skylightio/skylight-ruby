require 'rack'
require 'webrick'
require 'socket'
require 'thread'
require 'timeout'
require 'active_support'
require 'json'
require 'skylight/core/util/logging'
require 'puma/events'
require 'puma/server'

module SpecHelper
  class Server
    LOCK = Mutex.new
    COND = ConditionVariable.new

    def self.start(opts)
      @started or LOCK.synchronize do
        @started = true
        @server = Puma::Server.new(self, Puma::Events.new(STDOUT, STDERR))
        @server.add_tcp_listener("127.0.0.1", opts.fetch(:Port))
        @server_thread = @server.run
      end
    end

    def self.status
      @server_thread && @server_thread.status
    end

    def self.wait(opts = {})
      if Numeric === opts
        opts = { timeout: opts }
      end

      timeout = opts[:timeout] || EMBEDDED_HTTP_SERVER_TIMEOUT
      timeout_at = monotonic_time + timeout
      count = opts[:count] || 1
      filter = lambda { |r| opts[:resource] ? r['PATH_INFO'] == opts[:resource] : true }

      LOCK.synchronize do
        loop do
          return true if @requests.select(&filter).length >= count

          ttl = timeout_at - monotonic_time

          if ttl <= 0
            puts "***TIMEOUT***"
            puts "timeout: #{timeout}"
            puts "requests:"
            requests.each do |request|
              puts "#{Rack::Request.new(request).url}: #{!!filter.call(request)}"
            end
            puts "*************"
            raise "Server.wait timeout: got #{requests.select(&filter).length} not #{opts[:count]}"
          end

          COND.wait(LOCK, ttl)
        end
      end
    end

    def self.reset
      # FIXME
      # Crazy hack to make sure that the server has finished processing any inbound requests
      # This is necessary since sometimes we have situations where a request made in a previous
      # spec doesn't land until the next spec.
      sleep 0.1

      LOCK.synchronize do
        @requests = []
        @mocks = []
      end
    end

    def self.mock(path = nil, method = nil, &blk)
      LOCK.synchronize do
        @mocks << { path: path, method: method, blk: blk }
      end
    end

    def self.requests(resource = nil)
      reqs = LOCK.synchronize { @requests.dup } # FIXME: why?
      reqs.select! { |env| env['PATH_INFO'] == resource } if resource
      reqs
    end

    def self.reports
      requests.
        select { |env| env['PATH_INFO'] == '/report' }.
        map { |env| SpecHelper::Messages::Batch.decode(env['rack.input'].dup) }
    end

    def self.call(env)
      trace "%s http://%s:%s%s",
        env['REQUEST_METHOD'],
        env['SERVER_NAME'],
        env['SERVER_PORT'],
        env['PATH_INFO']

      ret = handle(env)

      trace "  -> %s", ret[0]
      trace "  -> %s", ret[2].join("\n")

      ret
    end

    def self.handle(env)
      if input = env.delete('rack.input')
        str = input.read.dup
        str.freeze

        if env['CONTENT_TYPE'] == 'application/json'
          str = JSON.parse(str)
        end

        env['rack.input'] = str
      end



      json = ['application/json', 'application/json; charset=UTF-8'].sample

      LOCK.synchronize do
        @requests << env
        COND.broadcast

        mock = @mocks.find do |m|
          (!m[:path] || m[:path] == env['PATH_INFO']) &&
            (!m[:method] || m[:method].to_s.upcase == env['REQUEST_METHOD'])
        end

        if mock
          @mocks.delete(mock)

          ret =
            begin
              mock[:blk].call(env)
            rescue => e
              trace "#{e.inspect}\n#{e.backtrace.map{|l| "  #{l}" }.join("\n")}"
              [ 500, { 'content-type' => 'text/plain', 'content-length' => '4' }, [ 'Fail' ] ]
            end

          if Array === ret
            return ret if ret.length == 3

            body = ret.last
            body = body.to_json if Hash === body

            return [ ret[0], { 'content-type' => json, 'content-length' => body.bytesize.to_s }, [body] ]
          elsif respond_to?(:to_str)
            return [ 200, { 'content-type' => 'text/plain', 'content-length' => ret.bytesize.to_s }, [ret] ]
          else
            ret = ret.to_json
            return [ 200, { 'content-type' => json, 'content-length' => ret.bytesize.to_s }, [ret] ]
          end
        end
      end

      [200, {'content-type' => 'text/plain', 'content-length' => '7'}, ['Thanks!']]
    end

    def self.trace(line, *args)
      if ENV['SKYLIGHT_ENABLE_TRACE_LOGS']
        printf("[HTTP Server] #{line}\n", *args)
      end
    end

    def self.monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  def server
    Server
  end

  def start_server(opts = {})
    opts[:Port]        ||= port
    opts[:environment] ||= 'test'
    # opts[:Logger]      ||= WEBrick::Log.new("/dev/null", 7)
    opts[:AccessLog]   ||= []
    opts[:debug]       ||= ENV['DEBUG']

    server.start(opts)
    server.reset
  end

  def port
    9292
  end

  def server_uri
    "http://127.0.0.1:#{port}"
  end

  def token
    "hey-guyz-i-am-a-token"
  end

  def stub_config_validation(status=200, response={})
    server.mock "/agent/config", :post do |env|
      expect(env['rack.input'].keys).to eq(['config'])
      [status, response]
    end
  end

  def stub_session_request
    server.mock "/agent" do |env|
      # TTL: 3 hours
      { auth: { session: { token: token, expiry_ttl: 10800 } } }
    end
  end

end
