module Skylight
  module Util
    module Proxy
      def self.detect_url(env)
        u = env['HTTP_PROXY'] || env['http_proxy']
        if u && !u.empty?
          u = "http://#{u}" unless u =~ %r[://]
          u
        end
      end
    end
  end
end