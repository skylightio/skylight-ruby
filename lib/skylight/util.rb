module Skylight
  module Util
    # Already defined by the native extension so we can't autoload
    require 'skylight/util/clock'

    autoload :AllocationFree, 'skylight/util/allocation_free'
    autoload :Conversions,    'skylight/util/conversions'
    autoload :Gzip,           'skylight/util/gzip'
    autoload :HTTP,           'skylight/util/http'
    autoload :Inflector,      'skylight/util/inflector'
    autoload :Logging,        'skylight/util/logging'
    autoload :Queue,          'skylight/util/queue'
    autoload :Task,           'skylight/util/task'
    autoload :UniformSample,  'skylight/util/uniform_sample'
    autoload :NativeExtFetcher, 'skylight/util/native_ext_fetcher'
  end
end