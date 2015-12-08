module Skylight
  # @api private
  module Util
    # Used from the main lib
    require 'skylight/util/allocation_free'
    require 'skylight/util/clock'
    require 'skylight/util/deploy'
    require 'skylight/util/hostname'
    require 'skylight/util/logging'
    require 'skylight/util/ssl'
    require 'skylight/util/http'

    # Used from the CLI
    autoload :Gzip,      'skylight/util/gzip'
    autoload :Inflector, 'skylight/util/inflector'
  end
end
