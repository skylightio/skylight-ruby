require 'uri'

module Skylight
  # @api private
  class Api
    include Util::Logging

    attr_reader :config, :http

    class CreateFailed < StandardError
      attr_reader :res

      def initialize(res)
        @res = res
        super "failed with status #{res.status}"
      end

      def errors
        return unless res.respond_to?(:body) && res.body.is_a?(Hash)
        res.body['errors']
      end

      def to_s
        if errors
          errors.inspect
        elsif res
          "#{res.class.to_s}: #{res.to_s}"
        else
          super
        end
      end
    end

    def initialize(config, service = :auth)
      @config = config
      @http   = Util::HTTP.new(config, service)
    end

    def authentication
      @http.authentication
    end

    def authentication=(token)
      @http.authentication = token
    end

    def validate_authentication
      url = URI.parse(config[:auth_url])

      res = @http.get(url.path)

      case res.status
      when 200...300
        :ok
      when 400...500
        :invalid
      else
        warn res.exception.message if res.exception
        :unknown
      end
    rescue => e
      warn e.message
      :unknown
    end

    def login(email, password)
      res = http.get('/me', 'X-Email' => email, 'X-Password' => password)

      if res && res.success?
        res.get('me.authentication_token')
      end
    end

    def create_app(name, token=nil)
      params = { app: { name: name } }
      params[:token] = token if token
      res = @http.post('/apps', params)
      raise CreateFailed, res unless res.success?
      res
    end

  end
end
