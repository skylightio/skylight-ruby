require 'tilde'
require 'rails'

module Tilde
  class Railtie < Rails::Railtie

    initialize :notifications do
      p [ :ZOMG ]
    end

  end
end
