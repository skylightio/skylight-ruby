require 'uri'
require 'json'
require 'openssl'
require 'net/http'
require 'net/https'
require 'skylight/util/gzip'
require 'skylight/util/ssl'

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

      include Logging

      attr_accessor :authentication
      attr_reader :host, :port

      READ_EXCEPTIONS = [Timeout::Error, EOFError]
      # This doesn't exist on Ruby 1.9.3
      READ_EXCEPTIONS << Net::ReadTimeout if defined?(Net::ReadTimeout)
      READ_EXCEPTIONS.freeze

      class StartError < StandardError
        attr_reader :original

        def initialize(e)
          @original = e
          super e.inspect
        end

      end

      class ReadResponseError < StandardError; end

      def initialize(config, service = :auth, opts = {})
        @config = config

        unless url = config["#{service}_url"]
          raise ArgumentError, "no URL specified"
        end

        url = URI.parse(url)

        @ssl  = url.scheme == 'https'
        @host = url.host
        @port = url.port

        if proxy_url = config[:proxy_url]
          proxy_url = URI.parse(proxy_url)
          @proxy_addr, @proxy_port = proxy_url.host, proxy_url.port
          @proxy_user, @proxy_pass = (proxy_url.userinfo || '').split(/:/)
        end

        @open_timeout = get_timeout(:connect, config, service, opts)
        @read_timeout = get_timeout(:read, config, service, opts)

        @deflate = config["#{service}_http_deflate"]
        @authentication = config[:'authentication']
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

      def get_timeout(type, config, service, opts)
        config.duration_ms("#{service}_http_#{type}_timeout") ||
          opts[:timeout] || 15
      end

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
          raise StartError, e
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

        http = Net::HTTP.new(@host, @port,
          @proxy_addr, @proxy_port, @proxy_user, @proxy_pass)

        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout

        if @ssl
          http.use_ssl = true

          unless SSL.ca_cert_file?
            http.ca_file = SSL.ca_cert_file_or_default
          end

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
