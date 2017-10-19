module Skylight::Core
  # @api private
  module Util
    # Used from the main lib
    require 'skylight/core/util/allocation_free'
    require 'skylight/core/util/clock'
    require 'skylight/core/util/deploy'
    require 'skylight/core/util/hostname'
    require 'skylight/core/util/logging'
    require 'skylight/core/util/ssl'
    require 'skylight/core/util/http'

    # Used from the CLI
    autoload :Gzip,      'skylight/core/util/gzip'
    autoload :Inflector, 'skylight/core/util/inflector'
  end
end
