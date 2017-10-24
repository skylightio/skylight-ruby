require 'skylight/version'
require 'skylight/native'
require 'skylight/core'
require 'skylight/api'
require 'skylight/config'

module Skylight
  # Used from the CLI
  autoload :CLI, 'skylight/cli'

  # Shorthand
  Helpers = Core::Helpers
  Middleware = Core::Middleware

  # Specifically check for Railtie since we've had at least one case of a
  #   customer having Rails defined without having all of Rails loaded.
  if defined?(Rails::Railtie)
    require 'skylight/railtie'
  end

  Core::Instrumenter.config_class = Config
end
