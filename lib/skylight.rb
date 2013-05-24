require 'rbconfig'
require 'socket'
require 'skylight/version'

module Skylight
  TRACE_ENV_KEY      = 'SK_ENABLE_TRACE_LOGS'.freeze
  STANDALONE_ENV_KEY = 'SK_STANDALONE'.freeze
  STANDALONE_ENV_VAL = 'server'.freeze

  def self.daemon?
    ENV[STANDALONE_ENV_KEY] == STANDALONE_ENV_VAL
  end

  unless daemon?
    require 'active_support/notifications'
    require 'skylight/compat' # Require after AS::N
  end

  autoload :Api,          'skylight/api'
  autoload :CLI,          'skylight/cli'
  autoload :Config,       'skylight/config'
  autoload :GC,           'skylight/gc'
  autoload :Instrumenter, 'skylight/instrumenter'
  autoload :Messages,     'skylight/messages'
  autoload :Middleware,   'skylight/middleware'
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
  class IpcProtoError    < RuntimeError; end
  class WorkerStateError < RuntimeError; end
  class ConfigError      < RuntimeError; end
  class TraceError       < RuntimeError; end

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
  Worker::Server.boot if daemon?

  if defined?(Rails)
    require 'skylight/railtie'
  end
end
