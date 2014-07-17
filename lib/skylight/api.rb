module Skylight
  # @api private
  class Api
    attr_reader :config, :http

    class CreateFailed < StandardError
      attr_reader :res

      def initialize(res)
        @res = res
        super "failed with status #{res.status}"
      end

      def errors
        return unless res.body.is_a?(Hash)
        res.body['errors']
      end
    end

    def initialize(config, service = :accounts)
      @config = config
      @http   = Util::HTTP.new(config, service)
    end

    def authentication
      @http.authentication
    end

    def authentication=(token)
      @http.authentication = token
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
