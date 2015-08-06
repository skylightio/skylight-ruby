module Skylight
  module Formatters
    module HTTP
      def self.build_opts(method, scheme, host, port, path, query)
        { category: "api.http.#{method.downcase}",
          title:    "#{method.upcase} #{host}" }
      end
    end
  end
end
