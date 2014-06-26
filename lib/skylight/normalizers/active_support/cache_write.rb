module Skylight
  module Normalizers
    module ActiveSupport
      class CacheWrite < Cache
        register "cache_write.active_support"

        CAT = "app.cache.write".freeze
        TITLE = "cache write"

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil, payload ]
        end
      end
    end
  end
end