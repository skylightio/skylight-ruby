module Skylight
  module Worker

    # === Constants
    CHUNK_SIZE = 16 * 1024

    # === Modules
    autoload :Builder,         'skylight/worker/builder'
    autoload :Collector,       'skylight/worker/collector'
    autoload :Connection,      'skylight/worker/connection'
    autoload :ConnectionSet,   'skylight/worker/connection_set'
    autoload :Embedded,        'skylight/worker/embedded'
    autoload :MetricsReporter, 'skylight/worker/metrics_reporter'
    autoload :Server,          'skylight/worker/server'
    autoload :Standalone,      'skylight/worker/standalone'

  end
end
