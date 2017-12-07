require 'skylight'
require 'skylight/probes/sinatra_add_middleware'
Skylight.probe(:sinatra, :tilt, :sequel)
