module Skylight
  module Normalizers
    module ActiveSupport
      class CacheClear < Cache
        register "cache_clear.active_support"

        CAT = "app.cache.clear".freeze
        TITLE = "cache clear".freeze

        def normalize(trace, name, payload)
          [ CAT, TITLE, nil ]
        end
      end
    end
  end
end
