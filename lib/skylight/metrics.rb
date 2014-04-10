module Skylight
  # @api private
  module Metrics
    autoload :Meter,           'skylight/metrics/meter'
    autoload :EWMA,            'skylight/metrics/ewma'
    autoload :ProcessMemGauge, 'skylight/metrics/process_mem_gauge'
    autoload :ProcessCpuGauge, 'skylight/metrics/process_cpu_gauge'
  end
end