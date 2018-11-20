require "rack"
require "active_support"
require "json"
require "skylight/core/util/logging"
require "puma/events"
require "puma/server"
require "delegate"

module SpecHelper
  class Server
    LOCK = Mutex.new
    COND = ConditionVariable.new

    class << self
      def start(opts)
        return if @started
        LOCK.synchronize do
          @started = true
          @server = Puma::Server.new(self, Puma::Events.new(STDOUT, STDERR))
          @server.add_tcp_listener("127.0.0.1", opts.fetch(:Port))
          @server_thread = @server.run
        end
      end

      def status
        @server_thread && @server_thread.status
      end

      def wait(opts = {})
        timeout = opts[:timeout] || EMBEDDED_HTTP_SERVER_TIMEOUT
        timeout_at = monotonic_time + timeout
        count = opts[:count] || 1
        filter = ->(r) { opts[:resource] ? r["PATH_INFO"] == opts[:resource] : true }

        LOCK.synchronize do
          loop do
            return true if filter_requests(opts).count(&filter) >= count

            ttl = timeout_at - monotonic_time

            if ttl <= 0
              puts "***TIMEOUT***"
              puts "timeout: #{timeout}"
              puts "seeking auth: #{opts[:authentication]}"
              puts "requests:"
              @requests.each do |request|
                puts "[auth: #{request['HTTP_AUTHORIZATION']}] #{Rack::Request.new(request).url}: #{!!filter.call(request)}"
              end
              puts "*************"
              raise "Server.wait timeout: got #{filter_requests(opts).count(&filter)} not #{opts[:count]}"
            end

            COND.wait(LOCK, ttl)
          end
        end
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

      def requests(opts = {})
        LOCK.synchronize do
          filter_requests(opts)
        end
      end

      def reports(opts = {})
        requests(opts)
          .select { |env| env["PATH_INFO"] == "/report" }
          .map { |env| SpecHelper::Messages::Batch.decode(env["rack.input"].dup) }
      end

      def call(env)
        trace "%s http://%s:%s%s",
              env["REQUEST_METHOD"],
              env["SERVER_NAME"],
              env["SERVER_PORT"],
              env["PATH_INFO"]

        ret = handle(env)

        trace "  -> %s", ret[0]
        trace "  -> %s", ret[2].join("\n")

        ret
      end

      private

      def handle(env)
        if (input = env.delete("rack.input"))
          str = input.read.dup
          str.freeze

          if env["CONTENT_TYPE"] == "application/json"
            str = JSON.parse(str)
          end

          env["rack.input"] = str
        end

        json = ["application/json", "application/json; charset=UTF-8"].sample

        LOCK.synchronize do
          @requests << env
          COND.broadcast

          mock = @mocks.find do |m|
            (!m[:path] || m[:path] == env["PATH_INFO"]) &&
              (!m[:method] || m[:method].to_s.upcase == env["REQUEST_METHOD"])
          end

          if mock
            @mocks.delete(mock)

            ret =
              begin
                mock[:blk].call(env)
              rescue => e
                trace "#{e.inspect}\n#{e.backtrace.map { |l| "  #{l}" }.join("\n")}"
                [500, { "content-type" => "text/plain", "content-length" => "4" }, ["Fail"]]
              end

            if ret.is_a?(Array)
              return ret if ret.length == 3

              body = ret.last
              body = body.to_json if body.is_a?(Hash)

              return [ret[0], { "content-type" => json, "content-length" => body.bytesize.to_s }, [body]]
            elsif respond_to?(:to_str)
              return [200, { "content-type" => "text/plain", "content-length" => ret.bytesize.to_s }, [ret]]
            else
              ret = ret.to_json
              return [200, { "content-type" => json, "content-length" => ret.bytesize.to_s }, [ret]]
            end
          end
        end

        [200, { "content-type" => "text/plain", "content-length" => "7" }, ["Thanks!"]]
      end

      def trace(line, *args)
        if ENV["SKYLIGHT_ENABLE_TRACE_LOGS"]
          printf("[HTTP Server] #{line}\n", *args)
        end
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def filter_requests(opts = {})
        @requests.select do |x|
          opts[:authentication] ? x["HTTP_AUTHORIZATION"].start_with?(opts[:authentication]) : true
        end
      end
    end
  end

  class ServerDelegate < SimpleDelegator
    # identifies requests made on THIS test specifically by passing the
    # authentication token to the server. Handles the cases in which a slow report
    # from a previous test could be made after a reset was requested.

    def wait(opts = {})
      if opts.is_a?(Numeric)
        opts = { timeout: opts }
      end

      __getobj__.wait(default_opts.merge(opts))
    end

    def requests(opts = {})
      __getobj__.requests(default_opts.merge(opts))
    end

    def reports(opts = {})
      __getobj__.reports(default_opts.merge(opts))
    end

    def set_authentication(auth)
      tap { @authentication = auth }
    end

    private

      def default_opts
        { authentication: @authentication }
      end
  end

  def server
    ServerDelegate.new(Server).set_authentication(token)
  end

  def start_server(opts = {})
    opts[:Port]        ||= port
    opts[:environment] ||= "test"
    opts[:AccessLog]   ||= []
    opts[:debug]       ||= ENV["DEBUG"]

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
    test_config_values[:authentication]
  end

  def stub_config_validation(status = 200, response = {})
    server.mock "/agent/config", :post do |env|
      expect(env["rack.input"].keys).to eq(["config"])
      [status, response]
    end
  end

  def stub_session_request
    server.mock "/agent" do |_env|
      # TTL: 3 hours
      { auth: { session: { token: token, expiry_ttl: 10800 } } }
    end
  end
end
