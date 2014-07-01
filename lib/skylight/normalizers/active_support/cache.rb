module Skylight
  module Normalizers
    module ActiveSupport
      # NOTE: Instrumentation may not be turned on by default and is possibly buggy
      # https://github.com/mperham/dalli/pull/284
      class Cache < Normalizer
        %w(clear
            decrement
            delete
            exist
            fetch_hit
            generate
            increment
            read
            read_multi
            write).each do |type|
          require "skylight/normalizers/active_support/cache_#{type}"
        end
      end
    end
  end
end

# See https://github.com/rails/rails/pull/15943
if defined?(ActiveSupport::Cache::Store.instrument)
  deprecated = false

  # If it's deprecated, setting to false will cause a deprecation warning
  # and the value will remain true
  ActiveSupport::Deprecation.silence do
    ActiveSupport::Cache::Store.instrument = false
    deprecated = ActiveSupport::Cache::Store.instrument
  end

  unless deprecated
    class ActiveSupport::Cache::Store
      def self.instrument
        true
      end

      def self.instrument=(val)
        unless val
          Rails.logger.warn "[WARNING] Skylight has patched ActiveSupport::Cache::Store.instrument to always be true. " \
                            "In future versions of Rails, this method will no longer be settable. " \
                            "See https://github.com/rails/rails/pull/15943 for more information."
        end
      end
    end
  end
end