require 'thread'
require 'socket'
require 'openssl'
require 'net/http'
require 'active_support/notifications'

module Skylight
  class Error < RuntimeError; end

  # First require all util files
  require 'skylight/util/atomic'
  require 'skylight/util/bytes'
  require 'skylight/util/clock'
  require 'skylight/util/ewma'
  require 'skylight/util/gzip'
  require 'skylight/util/queue'
  require 'skylight/util/uniform_sample'
  require 'skylight/util/uuid'

  # Then require the rest
  require 'skylight/compat'
  require 'skylight/config'
  require 'skylight/instrumenter'
  require 'skylight/middleware'
  require 'skylight/binary_proto'
  require 'skylight/json_proto'
  require 'skylight/subscriber'
  require 'skylight/trace'
  require 'skylight/worker'
end
