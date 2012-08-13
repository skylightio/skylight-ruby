require 'active_support/notifications'

module Tilde
  class Error < RuntimeError; end

  # TODO: Have smarter feature detection
  if true
    require 'tilde/notifications'
  end

  require 'tilde/instrumenter'
  require 'tilde/subscriber'
  require 'tilde/trace'
  require 'tilde/util'
end
