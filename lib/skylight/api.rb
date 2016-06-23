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

    def login(email, password)
      http.authentication = config[:authentication]
      res = http.get('/me', 'X-Email' => email, 'X-Password' => password)

      if res && res.success?
        res.get('me.authentication_token')
      end
    end

    def create_app(name, token=nil)
      params = { app: { name: name } }
      params[:token] = token if token

      http.authentication = config[:authentication]
      res = http.post('/apps', params)
      raise CreateFailed, res unless res.success?
      res
    end

  end
end
