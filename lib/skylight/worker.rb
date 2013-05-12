module Skylight
  module Worker

    # === Constants
    CHUNK_SIZE         = 16 * 1024
    STANDALONE_ENV_KEY = 'SK_STANDALONE'.freeze
    STANDALONE_ENV_VAL = 'server'.freeze
    LOCKFILE_PATH      = 'SK_LOCKFILE_PATH'.freeze
    LOCKFILE_ENV_KEY   = 'SK_LOCKFILE_FD'.freeze
    SOCKFILE_PATH_KEY  = 'SK_SOCKFILE_PATH'.freeze

    # === Modules
    autoload :Builder,    'skylight/worker/builder'
    autoload :Connection, 'skylight/worker/connection'
    autoload :Embedded,   'skylight/worker/embedded'
    autoload :Loop,       'skylight/worker/loop'
    autoload :Server,     'skylight/worker/server'
    autoload :Standalone, 'skylight/worker/standalone'

    def self.spawn
      Standalone.new
    end
  end
end
