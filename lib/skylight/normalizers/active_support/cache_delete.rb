module Skylight
  module Normalizers
    module ActiveSupport
      class CacheDelete < Cache
        register "cache_delete.active_support"

        CAT = "app.cache.delete".freeze
        TITLE = "cache delete".freeze

        def normalize(_trace, _name, _payload)
          [CAT, TITLE, nil]
        end
      end
    end
  end
end
