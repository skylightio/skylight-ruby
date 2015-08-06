module Skylight
  module Normalizers
    module ActiveSupport
      class CacheExist < Cache
        register "cache_exist?.active_support"

        CAT = "app.cache.exist".freeze
        TITLE = "cache exist?"

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil ]
        end
      end
    end
  end
end
