require 'skylight'
require 'skylight/probes/sinatra'
require 'skylight/probes/tilt'
require 'skylight/probes/sequel'

if Gem::Version(Sinatra::VERSION) < Gem::Version('1.4')
  Skylight::DEPRECATOR.deprecation_warning("Support for Sinatra versions before 1.4")
end
