require 'tilde'
require 'rails'

module Tilde
  class Railtie < Rails::Railtie

    initializer :notifications do
      Subscriber.register! Instrumenter.new
    end

  end
end
