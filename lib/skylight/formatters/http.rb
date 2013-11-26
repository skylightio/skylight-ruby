module Skylight
  module Formatters
    module HTTP

      def self.build_opts(method, scheme, host, port, path, query)
        category    = "api.http.#{method.downcase}"
        title       = "#{method.upcase} #{host || path}"
        description = "#{method.upcase} #{build_url(scheme, host, port, path, query)}"

        { category: category, title: title, description: description }
      end

      def self.build_url(scheme, host, port, path, query)
        url = ''
        if scheme
          url << "#{scheme}://"
        end
        if host
          url << host
        end
        if port
          url << ":#{port}"
        end
        url << path
        if query
          url << "?#{query}"
        end
        url
      end
    end
  end
end