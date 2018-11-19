module Skylight::Core
  module Normalizers
    module ActiveSupport
      class CacheExist < Cache
        register "cache_exist?.active_support"

        CAT = "app.cache.exist".freeze
        TITLE = "cache exist?".freeze

        def normalize(_trace, _name, _payload)
          [CAT, TITLE, nil]
        end
      end
    end
  end
end
