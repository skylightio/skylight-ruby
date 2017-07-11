require File.expand_path('../boot', __FILE__)

require 'action_controller/railtie'

Bundler.require(:default, Rails.env)

module Dummy
  class Application < Rails::Application
    # Make sure this is accessible when running the CLI - https://github.com/skylightio/skylight-ruby/issues/2
    config.skylight.environments += ['staging']
  end
end
