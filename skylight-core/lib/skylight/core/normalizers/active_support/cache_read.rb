module Skylight::Core
  module Normalizers
    module ActiveSupport
      class CacheRead < Cache
        register "cache_read.active_support"

        CAT = "app.cache.read".freeze
        TITLE = "cache read".freeze

        def normalize(_trace, _name, _payload)
          [CAT, TITLE, nil]
        end
      end
    end
  end
end
