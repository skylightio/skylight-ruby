module Skylight
  module Formatters
    module HTTP
      def self.build_opts(method, scheme, host, port, path, query)
        { category: "api.http.#{method.downcase}",
          title:    "#{method.upcase} #{host}",
          annotations: {
            method: method.upcase,
            scheme: scheme,
            host:   host,
            port:   port ? port.to_i : nil,
            path:   path,
            query:  query }}
      end
    end
  end
end