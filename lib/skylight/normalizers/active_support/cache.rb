module Skylight
  module Normalizers
    module ActiveSupport
      class Cache < Normalizer
        %w[clear decrement delete exist fetch_hit generate increment read read_multi write].each do |type|
          require "skylight/normalizers/active_support/cache_#{type}"
        end
      end
    end
  end
end
