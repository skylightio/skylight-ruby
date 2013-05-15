module Skylight
  module Worker

    # === Constants
    CHUNK_SIZE         = 16 * 1024
    STANDALONE_ENV_KEY = 'SK_STANDALONE'.freeze
    STANDALONE_ENV_VAL = 'server'.freeze
    LOCKFILE_PATH      = 'SK_LOCKFILE_PATH'.freeze
    LOCKFILE_ENV_KEY   = 'SK_LOCKFILE_FD'.freeze
    SOCKFILE_PATH_KEY  = 'SK_SOCKFILE_PATH'.freeze
    UDS_SRV_FD_KEY     = 'SK_UDS_FD'.freeze

    # === Modules
    autoload :Builder,    'skylight/worker/builder'
    autoload :Collector,  'skylight/worker/collector'
    autoload :Connection, 'skylight/worker/connection'
    autoload :Embedded,   'skylight/worker/embedded'
    autoload :Server,     'skylight/worker/server'
    autoload :Standalone, 'skylight/worker/standalone'

    class IpcProtoError < RuntimeError; end

    def self.spawn
      Standalone.new
    end
  end
end
