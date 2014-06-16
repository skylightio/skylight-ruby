require 'json'
require 'openssl'
require 'net/http'
require 'net/https'

module Skylight
  module Util
    class HTTP
      CONTENT_ENCODING = 'content-encoding'.freeze
      CONTENT_LENGTH   = 'content-length'.freeze
      CONTENT_TYPE     = 'content-type'.freeze
      ACCEPT           = 'Accept'.freeze
      X_VERSION_HDR    = 'x-skylight-agent-version'.freeze
      APPLICATION_JSON = 'application/json'.freeze
      AUTHORIZATION    = 'authorization'.freeze
      DEFLATE          = 'deflate'.freeze
      GZIP             = 'gzip'.freeze
      DEFAULT_CA_FILE  = File.expand_path('../../data/cacert.pem', __FILE__)

      include Logging

      attr_accessor :authentication
      attr_reader :host, :port

      READ_EXCEPTIONS = [Timeout::Error, EOFError]
      # This doesn't exist on Ruby 1.9.3
      READ_EXCEPTIONS << Net::ReadTimeout if defined?(Net::ReadTimeout)
      READ_EXCEPTIONS.freeze

      class StartError < StandardError; end
      class ReadResponseError < StandardError; end

      def initialize(config, service = :report, opts = {})
        @config = config
        @ssl  = config["#{service}.ssl"]
        @host = config["#{service}.host"]
        @port = config["#{service}.port"]

        @proxy_addr = config["#{service}.proxy_addr"]
        @proxy_port = config["#{service}.proxy_port"]
        @proxy_user = config["#{service}.proxy_user"]
        @proxy_pass = config["#{service}.proxy_pass"]

        @timeout = opts[:timeout] || 15

        unless @proxy_addr
          if http_proxy = ENV['HTTP_PROXY'] || ENV['http_proxy']
            uri = URI.parse(http_proxy)
            @proxy_addr, @proxy_port = uri.host, uri.port
            @proxy_user, @proxy_pass = (uri.userinfo || '').split(/:/)
          end
        end

        @deflate = config["#{service}.deflate"]
        @authentication = config[:'authentication']
      end

      def self.detect_ca_cert_file!
        @ca_cert_file = false
        if defined?(OpenSSL::X509::DEFAULT_CERT_FILE)
          if OpenSSL::X509::DEFAULT_CERT_FILE
            @ca_cert_file = File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
          end
        end
      end

      detect_ca_cert_file!

      def self.ca_cert_file?
        @ca_cert_file
      end

      def get(endpoint, hdrs = {})
        request = build_request(Net::HTTP::Get, endpoint, hdrs)
        execute(request)
      end

      def post(endpoint, body, hdrs = {})
        unless body.respond_to?(:to_str)
          hdrs[CONTENT_TYPE] = APPLICATION_JSON
          body = body.to_json
        end

        request = build_request(Net::HTTP::Post, endpoint, hdrs, body.bytesize)
        execute(request, body)
      end

    private

      def build_request(type, endpoint, hdrs, length=nil)
        headers = {}

        headers[CONTENT_LENGTH]   = length.to_s if length
        headers[AUTHORIZATION]    = authentication if authentication
        headers[ACCEPT]           = APPLICATION_JSON
        headers[X_VERSION_HDR]    = VERSION
        headers[CONTENT_ENCODING] = GZIP if length && @deflate

        hdrs.each do |k, v|
          headers[k] = v
        end

        type.new(endpoint, headers)
      end

      def do_request(http, req)
        begin
          client = http.start
        rescue => e
          # TODO: Retry here
          raise StartError, e.inspect
        end

        begin
          res = client.request(req)
        rescue *READ_EXCEPTIONS => e
          raise ReadResponseError, e.inspect
        end

        yield res
      ensure
        client.finish if client
      end

      def execute(req, body=nil)
        t { fmt "executing HTTP request; host=%s; port=%s; path=%s, body=%s",
              @host, @port, req.path, body && body.bytesize }

        if body
          body = Gzip.compress(body) if @deflate
          req.body = body
        end

        http = Net::HTTP.new(@host, @port, @proxy_addr, @proxy_port, @proxy_user, @proxy_pass)

        http.open_timeout = @timeout
        http.read_timeout = @timeout

        if @ssl
          http.use_ssl = true
          http.ca_file = DEFAULT_CA_FILE unless HTTP.ca_cert_file?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        do_request(http, req) do |res|
          unless res.code =~ /2\d\d/
            debug "server responded with #{res.code}"
            t { fmt "body=%s", res.body }
          end

          Response.new(res.code.to_i, res, res.body)
        end
      rescue Exception => e
        error "http %s %s failed; error=%s; msg=%s", req.method, req.path, e.class, e.message
        t { e.backtrace.join("\n") }
        ErrorResponse.new(req, e)
      end

      class Response
        attr_reader :status, :headers, :body, :exception

        def initialize(status, headers, body)
          @status  = status
          @headers = headers

          if (headers[CONTENT_TYPE] || "").include?(APPLICATION_JSON)
            begin
              @body = JSON.parse(body)
            rescue JSON::ParserError
              @body = body # not really JSON I guess
            end
          else
            @body = body
          end
        end

        def success?
          status >= 200 && status < 300
        end

        def to_s
          body.to_s
        end

        def get(key)
          return nil unless Hash === body

          res = body
          key.split('.').each do |part|
            return unless res = res[part]
          end
          res
        end

        def respond_to_missing?(name, include_all=false)
          super || body.respond_to?(name, include_all)
        end

        def method_missing(name, *args, &blk)
          if respond_to_missing?(name)
            body.send(name, *args, &blk)
          else
            super
          end
        end
      end

      class ErrorResponse < Struct.new(:request, :exception)
        def status
          nil
        end

        def success?
          false
        end
      end

    end
  end
end
