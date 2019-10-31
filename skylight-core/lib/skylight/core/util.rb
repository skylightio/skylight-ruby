module Skylight::Core
  # @api private
  module Util
    # Used from the main lib
    require "skylight/core/util/allocation_free"
    require "skylight/core/util/clock"

    # Used from the CLI
    autoload :Gzip,      "skylight/core/util/gzip"
    autoload :Inflector, "skylight/core/util/inflector"
  end
end
