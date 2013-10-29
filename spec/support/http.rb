require 'rack'
require 'webrick'
require 'socket'
require 'thread'
require 'timeout'

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
        @inst = Server.new
        @rack = Rack::Server.start(opts.merge(app: @inst))
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
      opts[:timeout] ||= ENV['TRAVIS'] ? 15 : 4

      now = Time.now

      until requests.length == opts[:count]
        return false if opts[:timeout] <= Time.now - now
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

    def requests
      LOCK.synchronize { @requests.dup }
    end

    def reports
      requests.
        select { |env| env['PATH_INFO'] == '/report' }.
        map { |env| Skylight::Messages::Batch.decode(env['rack.input'].dup) }
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
            ret = mock[:blk].call(env)

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
          rescue Exception => e
            puts e.message
            puts e.backtrace
            return [
              500,
              { 'content-type' => 'text/plain',
                'content-length' => '4' },
              ['Fail'] ]
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

  def token
    "hey-guyz-i-am-a-token"
  end

  def stub_session_request
    server.mock "/agent/authenticate" do |env|
      { session: { token: token} }
    end
  end

end
