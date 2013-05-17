module Skylight
  module Worker

    # === Constants
    CHUNK_SIZE = 16 * 1024

    # === Modules
    autoload :Builder,    'skylight/worker/builder'
    autoload :Collector,  'skylight/worker/collector'
    autoload :Connection, 'skylight/worker/connection'
    autoload :Embedded,   'skylight/worker/embedded'
    autoload :Server,     'skylight/worker/server'
    autoload :Standalone, 'skylight/worker/standalone'

    def self.spawn
      Standalone.new
    end
  end
end
