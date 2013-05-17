require 'socket'
require 'skylight/version'

module Skylight
  autoload :Messages, 'skylight/messages'
  autoload :Worker,   'skylight/worker'

  module Util
    autoload :Logging, 'skylight/util/logging'
    autoload :Queue,   'skylight/util/queue'
    autoload :Task,    'skylight/util/task'
  end

  # ==== Vendor ====
  autoload :Beefcake, 'skylight/vendor/beefcake'

  # ==== Exceptions ====
  class IpcProtoError < RuntimeError; end
  class WorkerStateError < RuntimeError; end

  # Called by the standalone agent
  Worker::Server.boot
end
