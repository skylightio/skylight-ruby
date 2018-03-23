module Skylight::Core
  # @api private
  module Util
    # Used from the main lib
    require 'skylight/core/util/allocation_free'
    require 'skylight/core/util/clock'
    require 'skylight/core/util/logging'

    # Used from the CLI
    autoload :Gzip,      'skylight/core/util/gzip'
    autoload :Inflector, 'skylight/core/util/inflector'
  end
end
