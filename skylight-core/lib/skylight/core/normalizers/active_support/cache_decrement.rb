module Skylight::Core
  module Normalizers
    module ActiveSupport
      class CacheDecrement < Cache
        register "cache_decrement.active_support"

        CAT = "app.cache.decrement".freeze
        TITLE = "cache decrement".freeze

        def normalize(_trace, _name, _payload)
          [CAT, TITLE, nil]
        end
      end
    end
  end
end
