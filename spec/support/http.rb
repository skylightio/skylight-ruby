require 'rack'
require 'webrick'
require 'socket'
require 'thread'
require 'timeout'
require 'active_support'
require 'json'

module SpecHelper
  class Server
    LOCK = Mutex.new

    def self.singleton
      @inst
    end

    def self.start(opts)
      return if @started
      port = opts[:Port]

      @started = true
      @thread = Thread.new do
        begin
          @inst = Server.new
          @rack = Rack::Server.new(opts.merge(app: @inst))
          # Rack 1.2 (required by Rails 3.0) has a bug that prevents setting the app properly
          @rack.instance_variable_set('@app', @inst )
          @rack.start
        rescue Exception => e
          # Prevent errors from being silently swallowed
          puts e.inspect
          puts e.backtrace
        end
      end

      Timeout.timeout(30) do
        begin
          sock = TCPSocket.new 'localhost', port
          sock.close
        rescue Errno::ECONNREFUSED
          sleep 1
          retry
        end
      end
    end

    def initialize
      reset
    end

    def wait(opts = {})

      if Numeric === opts
        opts = { timeout: opts }
      end

      opts[:count]   ||= 1
      opts[:timeout] ||= EMBEDDED_HTTP_SERVER_TIMEOUT

      filter = lambda { |r| true }
      filter = lambda { |r| r['PATH_INFO'] == opts[:resource] } if opts[:resource]

      now = Time.now

      until requests.select(&filter).length >= opts[:count]
        diff = Time.now - now
        if opts[:timeout] <= diff
          puts "***TIMEOUT***"
          puts "timeout: #{opts[:timeout]}"
          puts "diff: #{diff}"
          puts requests.select(&filter).inspect
          puts "*************"
          raise "Server.wait timeout: got #{requests.select(&filter).length} not #{opts[:count]}"
        end
        sleep 0.1
      end

      true
    end

    def reset
      LOCK.synchronize do
        @requests = []
        @mocks = []
      end
    end

    def mock(path = nil, method = nil, &blk)
      LOCK.synchronize do
        @mocks << { path: path, method: method, blk: blk }
      end
    end

    def requests(resource = nil)
      reqs = LOCK.synchronize { @requests.dup }
      reqs.select! { |env| env['PATH_INFO'] == resource } if resource
      reqs
    end

    def reports
      requests.
        select { |env| env['PATH_INFO'] == '/report' }.
        map { |env| SpecHelper::Messages::Batch.decode(env['rack.input'].dup) }
    end

    def call(env)
      if input = env.delete('rack.input')
        str = input.read.dup
        str.freeze

        if env['CONTENT_TYPE'] == 'application/json'
          str = JSON.parse(str)
        end

        env['rack.input'] = str
      end

      json = ['application/json', 'application/json; charset=UTF-8'].shuffle.first

      LOCK.synchronize do
        @requests << env

        mock = @mocks.find do |m|
          (!m[:path] || m[:path] == env['PATH_INFO']) &&
            (!m[:method] || m[:method].to_s.upcase == env['REQUEST_METHOD'])
        end

        if mock
          @mocks.delete(mock)

          begin
            ret =
              begin
                mock[:blk].call(env)
              rescue
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
      end

      [200, {'content-type' => 'text/plain', 'content-length' => '7'}, ['Thanks!']]
    end
  end

  def server
    Server.singleton
  end

  def start_server(opts = {})
    opts[:Port]        ||= port
    opts[:environment] ||= 'test'
    opts[:Logger]      ||= WEBrick::Log.new("/dev/null", 7)
    opts[:AccessLog]   ||= []

    Server.start(opts)
    server.reset
  end

  def port
    9292
  end

  def server_uri
    "http://localhost:#{port}"
  end

  def token
    "hey-guyz-i-am-a-token"
  end

  def stub_token_verification(status=200)
    server.mock "/agent/authenticate" do |env|
      [status, { session: { token: token, expires_at: 3.hours.from_now.to_i } }]
    end
  end

  def stub_session_request
    server.mock "/agent/authenticate" do |env|
      { session: { token: token, expires_at: 3.hours.from_now.to_i } }
    end
  end

end
