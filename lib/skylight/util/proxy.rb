module Skylight
  module Util
    module Proxy
      def self.detect_url(env)
        if u = env['HTTP_PROXY'] || env['http_proxy']
          u = "http://#{u}" unless u =~ %r[://]
          u
        end
      end
    end
  end
end