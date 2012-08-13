require 'thread'
require 'active_support/notifications'

module Tilde
  class Error < RuntimeError; end

  # TODO: Have smarter feature detection
  if true
    require 'tilde/notifications'
  end

  require 'tilde/instrumenter'
  require 'tilde/middleware'
  require 'tilde/subscriber'
  require 'tilde/trace'
  require 'tilde/util'
  require 'tilde/worker'
end
