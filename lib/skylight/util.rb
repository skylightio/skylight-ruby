module Skylight
  # @api private
  module Util
    # Used from the main lib
    require "skylight/util/allocation_free"
    require "skylight/util/clock"
    require "skylight/util/instrumenter_method"

    # Used from the CLI
    autoload :Gzip, "skylight/util/gzip"
  end
end
