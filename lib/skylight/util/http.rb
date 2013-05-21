require 'json'
require 'net/http'

module Skylight
  module Util
    class HTTP
      CONTENT_ENCODING = 'content-encoding'.freeze
      CONTENT_LENGTH   = 'content-length'.freeze
      CONTENT_TYPE     = 'content-type'.freeze
      ACCEPT           = 'Accept'.freeze
      APPLICATION_JSON = 'application/json'.freeze
      AUTHORIZATION    = 'authorization'.freeze
      DEFLATE          = 'deflate'.freeze
      GZIP             = 'gzip'.freeze

      include Logging

      attr_accessor :authentication, :config

      def initialize(config)
        @ssl  = config[:'report.ssl']
        @host = config[:'report.host']
        @port = config[:'report.port']
        @deflate = config[:'report.deflate']
        @authentication = config[:'authentication']
      end

      def post(endpoint, body, hdrs = {})
        request = build_request(Net::HTTP::Post, endpoint, body.bytesize)

        hdrs.each do |k, v|
          request[k] = v
        end

        execute(request, body)
      rescue Exception => e
        error "http post failed; msg=%s", e.message
        puts e.backtrace
      end

    private

      def build_request(type, endpoint, length=nil)
        headers = {}

        headers[CONTENT_LENGTH]   = length.to_s if length
        headers[AUTHORIZATION]    = authentication if authentication
        headers[CONTENT_TYPE]     = APPLICATION_JSON if length
        headers[ACCEPT]           = APPLICATION_JSON
        headers[CONTENT_ENCODING] = GZIP if @deflate

        type.new(endpoint, headers)
      end

      def execute(req, body=nil, headers={})
        trace "executing HTTP request; host=%s; port=%s", @host, @port

        if body
          body = Gzip.compress(body) if @deflate
          req.body = body
        end

        headers.each do |name, value|
          req[name] = value
        end

        http = Net::HTTP.new @host, @port

        if @ssl
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        http.start do |client|
          response = client.request(req)

          unless response.code == '200'
            debug "Server responded with #{response.code}"
          end

          return response.body
        end
      end

    end
  end
end
