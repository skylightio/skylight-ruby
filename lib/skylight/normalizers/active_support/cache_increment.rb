module Skylight
  module Normalizers
    module ActiveSupport
      class CacheIncrement < Cache
        register "cache_increment.active_support"

        CAT = "app.cache.increment".freeze
        TITLE = "cache increment"

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil ]
        end
      end
    end
  end
end
