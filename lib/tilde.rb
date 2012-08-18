require 'thread'
require 'socket'
require 'zlib'
require 'openssl'
require 'net/http'
require 'active_support/notifications'

module Tilde
  class Error < RuntimeError; end

  # First require all util files
  require 'tilde/util/atomic'
  require 'tilde/util/bytes'
  require 'tilde/util/clock'
  require 'tilde/util/ewma'
  require 'tilde/util/queue'
  require 'tilde/util/uniform_sample'
  require 'tilde/util/uuid'

  # Then require the rest
  require 'tilde/compat'
  require 'tilde/config'
  require 'tilde/instrumenter'
  require 'tilde/middleware'
  require 'tilde/proto'
  require 'tilde/subscriber'
  require 'tilde/trace'
  require 'tilde/worker'
end
