require 'skylight/version'
require 'skylight/core'
require 'skylight/trace'
require 'skylight/instrumenter'
require 'skylight/api'
require 'skylight/config'
require 'skylight/native'

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

  include Core::Instrumentable

  def self.instrumenter_class
    Instrumenter
  end

  def self.config_class
    Config
  end
end
