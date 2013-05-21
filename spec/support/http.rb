require 'rack'
require 'webrick'
require 'socket'
require 'thread'

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

      begin
        sock = TCPSocket.new 'localhost', port
        sock.close
      rescue Errno::ECONNREFUSED
        sleep 1
        retry
      end
    end

    def initialize
      reset
    end

    def wait(timeout = 2)
      now = Time.now

      until !requests.empty?
        return false if timeout <= Time.now - now
        sleep 0.1
      end

      true
    end

    def reset
      LOCK.synchronize do
        @requests = []
      end
    end

    def requests
      LOCK.synchronize { @requests.dup }
    end

    def reports
      requests.
        select { |env| env['PATH_INFO'] == '/agent/report' }.
        map { |env| Skylight::Messages::Batch.decode(env['rack.input'].dup) }
    end

    def call(env)
      if input = env.delete('rack.input')
        str = input.read.dup
        str.freeze

        env['rack.input'] = str
      end

      LOCK.synchronize do
        @requests << env
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
  end

  def port
    9292
  end

end
