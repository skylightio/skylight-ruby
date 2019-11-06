module Skylight
  module Normalizers
    module ActiveSupport
      class CacheGenerate < Cache
        register "cache_generate.active_support"

        CAT = "app.cache.generate".freeze
        TITLE = "cache generate".freeze

        def normalize(_trace, _name, _payload)
          [CAT, TITLE, nil]
        end
      end
    end
  end
end
