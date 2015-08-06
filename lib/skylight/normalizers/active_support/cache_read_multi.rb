module Skylight
  module Normalizers
    module ActiveSupport
      class CacheReadMulti < Cache
        register "cache_read_multi.active_support"

        CAT = "app.cache.read_multi".freeze
        TITLE = "cache read multi"

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil ]
        end
      end
    end
  end
end
