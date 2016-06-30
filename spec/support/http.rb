require 'rack'
require 'webrick'
require 'socket'
require 'thread'
require 'timeout'
require 'active_support'
require 'json'
require 'skylight/util/logging'

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

          # If we get here then we got a Ctrl-C which we really wanted RSpec to catch
          LOCK.synchronize do
            # Yes, this is a private API, but we want to let RSpec shut down cleanly
            RSpec.wants_to_quit = true
          end
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

    def self.status
      @thread && @thread.status
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
        # Server isn't running so this won't succeed anyway
        unless Server.status
          raise "Server stopped"
        end

        diff = Time.now - now
        if opts[:timeout] <= diff
          puts "***TIMEOUT***"
          puts "timeout: #{opts[:timeout]}"
          puts "diff: #{diff}"
          puts "requests:"
          requests.each do |request|
            puts "#{Rack::Request.new(request).url}: #{!!filter.call(request)}"
          end
          puts "*************"
          raise "Server.wait timeout: got #{requests.select(&filter).length} not #{opts[:count]}"
        end
        sleep 0.1
      end

      true
    end

    def reset
      # Crazy hack to make sure that the server has finished processing any inbound requests
      # This is necessary since sometimes we have situations where a request made in a previous
      # spec doesn't land until the next spec.
      sleep 0.1

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

    def handle(env)
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

    def trace(line, *args)
      if Skylight::Util::Logging.trace?
        printf("[HTTP Server] #{line}\n", *args)
      end
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
    opts[:debug]       ||= ENV['DEBUG']

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

  def stub_config_validation(status=200, response={})
    server.mock "/agent/config", :post do |env|
      expect(env['rack.input'].keys).to eq(['config'])
      [status, response]
    end
  end

  def stub_session_request
    server.mock "/agent" do |env|
      { auth: { session: { token: token, expiry_ttl: 3.hours.to_i } } }
    end
  end

end
