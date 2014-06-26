module Skylight
  module Normalizers
    module ActiveSupport
      class CacheRead < Cache
        register "cache_read.active_support"

        CAT = "app.cache.read".freeze
        TITLE = "cache read"

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil, payload ]
        end
      end
    end
  end
end