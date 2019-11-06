module Skylight
  module Formatters
    module HTTP
      # Build instrumentation options for HTTP queries
      #
      # @param [String] method HTTP method, e.g. get, post
      # @param [String] scheme HTTP scheme, e.g. http, https
      # @param [String] host Request host, e.g. example.com
      # @param [String, Integer] port Request port
      # @param [String] path Request path
      # @param [String] query Request query string
      # @return [Hash] a hash containing `:category`, `:title`, and `:annotations`
      def self.build_opts(method, _scheme, host, _port, _path, _query)
        { category: "api.http.#{method.downcase}",
          title:    "#{method.upcase} #{host}",
          meta:     { host: host } }
      end
    end
  end
end
