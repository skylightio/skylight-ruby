module Skylight
  module Normalizers
    module ActiveSupport
      class CacheDelete < Cache
        register "cache_delete.active_support"

        CAT = "app.cache.delete".freeze
        TITLE = "cache delete"

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil ]
        end
      end
    end
  end
end
