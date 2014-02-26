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

      attr_accessor :authentication, :config

      def initialize(config, service = :report)
        @config = config
        @ssl  = config["#{service}.ssl"]
        @host = config["#{service}.host"]
        @port = config["#{service}.port"]
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

      def execute(req, body=nil)
        t { fmt "executing HTTP request; host=%s; port=%s; path=%s, body=%s",
              @host, @port, req.path, body && body.bytesize }

        if body
          body = Gzip.compress(body) if @deflate
          req.body = body
        end

        http = Net::HTTP.new @host, @port

        if @ssl
          http.use_ssl = true
          http.ca_file = DEFAULT_CA_FILE unless HTTP.ca_cert_file?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        http.start do |client|
          res = client.request(req)

          unless res.code =~ /2\d\d/
            debug "server responded with #{res.code}"
            t { fmt "body=%s", res.body }
          end

          Response.new(res.code.to_i, res, res.body)
        end
      rescue Exception => e
        error "http %s failed; error=%s; msg=%s", req.method, e.class, e.message
        t { e.backtrace.join("\n") }
        ErrorResponse.new(req.method, e)
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

      class ErrorResponse < Struct.new(:request_method, :exception)
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
