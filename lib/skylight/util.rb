module Skylight
  # @api private
  module Util
    # Used from the main lib
    require 'skylight/util/allocation_free'
    require 'skylight/util/clock'
    require 'skylight/util/hostname'
    require 'skylight/util/logging'
    require 'skylight/util/ssl'

    # Used from the CLI
    autoload :Gzip,      'skylight/util/gzip'
    autoload :HTTP,      'skylight/util/http'
    autoload :Inflector, 'skylight/util/inflector'
  end
end
