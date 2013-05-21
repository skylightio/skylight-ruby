require 'rbconfig'
require 'socket'
require 'skylight/version'
require 'active_support/notifications'
require 'skylight/compat' # Require after AS::N

module Skylight
  autoload :Config,       'skylight/config'
  autoload :Instrumenter, 'skylight/instrumenter'
  autoload :Messages,     'skylight/messages'
  autoload :Normalizers,  'skylight/normalizers'
  autoload :Subscriber,   'skylight/subscriber'
  autoload :Worker,       'skylight/worker'

  module Util
    autoload :Clock,         'skylight/util/clock'
    autoload :Gzip,          'skylight/util/gzip'
    autoload :HTTP,          'skylight/util/http'
    autoload :Logging,       'skylight/util/logging'
    autoload :Queue,         'skylight/util/queue'
    autoload :Task,          'skylight/util/task'
    autoload :UniformSample, 'skylight/util/uniform_sample'
  end

  # ==== Vendor ====
  autoload :Beefcake, 'skylight/vendor/beefcake'

  # ==== Exceptions ====
  class IpcProtoError < RuntimeError; end
  class WorkerStateError < RuntimeError; end

  TIERS = %w(
    app
    view
    db
    noise
    other)

  RUBYBIN = File.join(
    RbConfig::CONFIG['bindir'],
    "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}")

  # Called by the standalone agent
  Worker::Server.boot
end
