require 'skylight'

if Gem::Version(Sinatra::VERSION) < Gem::Version('1.4')
  Skylight::DEPRECATOR.deprecation_warning("Support for Sinatra versions before 1.4")
end

Skylight.probe(:sinatra, :tilt, :sequel)
