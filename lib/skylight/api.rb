require 'uri'

module Skylight
  # @api private
  class Api
    include Util::Logging

    attr_reader :config

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

    class ConfigValidationResults

      include Util::Logging

      attr_reader :raw_response

      def initialize(config, raw_response)
        @config = config
        @raw_response = raw_response
      end

      def is_error_response?
        raw_response.is_a?(Util::HTTP::ErrorResponse) || status > 499
      end

      def status
        raw_response.status
      end

      def body
        return nil if is_error_response?

        unless raw_response.body.is_a?(Hash)
          warn("Unable to parse server response: status=%s, body=%s", raw_response.status, raw_response.body)
          return {}
        end

        raw_response.body
      end

      def token_valid?
        # Don't prevent boot if it's an error response, so assume token is valid
        return true if is_error_response?
        # A 2xx response means everything is good!
        return true if raw_response.success?
        # A 422 means an invalid config, but the token must be valid if we got this far
        return true if status === 422
      end

      def config_valid?
        # Only assume config is good if we have positive confirmation
        raw_response.success?
      end

      def validation_errors
        return if config_valid?
        body ? body['errors'] : nil
      end

      def corrected_config
        return if config_valid?
        body ? body['corrected'] : nil
      end

    end

    def initialize(config)
      @config = config
    end

    def create_app(name, token=nil)
      params = { app: { name: name } }
      params[:token] = token if token

      res = http_request(:app_create, :post, params)

      raise CreateFailed, res unless res.success?
      res
    end

    def validate_config
      res = http_request(:validation, :post, config)
      ConfigValidationResults.new(config, res)
    end

    private

    # TODO: Improve handling here: https://github.com/tildeio/direwolf-agent/issues/274
    def http_request(service, method, *args)
      http = Util::HTTP.new(config, service)
      uri = URI.parse(config.get("#{service}_url"))
      http.send(method, uri.path, *args)
    end

  end
end
