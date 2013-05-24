module Skylight
  class Api
    include Util::Logging

    attr_reader :config, :http

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

    def create_app(name)
      res = @http.post('/apps', { app: { name: name }})
      res if res.success?
    end

  end
end
