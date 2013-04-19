require "json"

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

      def initialize(config)
        @config = config
      end

      def auth(username, password)
        req = Net::HTTP::Get.new("/login")
        req.basic_auth username, password
        response = make_request(req, nil, ACCEPT => APPLICATION_JSON)
        JSON.parse(response)
      end

      def create_app(user_token, app_name)
        req = Net::HTTP::Post.new("/apps")
        req["Authorization"] = user_token

        body = JSON.dump(app: { name: app_name })
        headers = { ACCEPT => APPLICATION_JSON }
        headers[CONTENT_TYPE] = APPLICATION_JSON
        headers[CONTENT_ENCODING] = GZIP if @config.deflate?
        response = make_request(req, body, headers)

        JSON.parse(response)
      end

      def post(endpoint, body)
        req = request(Net::HTTP::Post, endpoint, body.bytesize)
        make_request(req, body)
      rescue => e
        logger.error "[SKYLIGHT] POST #{@config.host}:#{@config.port}(ssl=#{@config.ssl?}) - #{e.message} - #{e.class} - #{e.backtrace.first}"
        debug(e.backtrace.join("\n"))
      end

      def request(type, endpoint, length=nil)
        headers = {}

        headers[CONTENT_LENGTH]   = length.to_s if length
        headers[AUTHORIZATION]    = @config.authentication_token
        headers[CONTENT_TYPE]     = APPLICATION_JSON if length
        headers[ACCEPT]           = APPLICATION_JSON
        headers[CONTENT_ENCODING] = GZIP if @config.deflate?

        type.new(endpoint, headers)
      end

    private
      def make_request(req, body=nil, headers={})
        if body
          body = Gzip.compress(body) if @config.deflate?
          req.body = body
        end

        headers.each do |name, value|
          req[name] = value
        end

        http = Net::HTTP.new @config.host, @config.port

        if @config.ssl?
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

      def logger
        @config.logger
      end

      def debug(msg)
        logger.debug "[SKYLIGHT] #{msg}" if logger.debug?
      end
    end
  end
end
