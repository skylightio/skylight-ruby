require 'active_support/notifications'

module Tilde
  class Error < RuntimeError; end

  # TODO: Have smarter feature detection
  if true
    require 'tilde/notifications'
  end

  # Require the juicy bits
  require 'tilde/direwolf_native'

  require 'tilde/instrumenter'
  require 'tilde/subscriber'
  require 'tilde/tracer'
  require 'tilde/util'
end
