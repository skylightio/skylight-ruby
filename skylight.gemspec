$:.push "#{File.expand_path('..', __FILE__)}/lib"

# Maintain your gem's version:
require "skylight/version"

Gem::Specification.new do |s|
  s.name        = "skylight"
  s.version     = Skylight::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tilde, Inc."]
  s.email       = ["engineering@tilde.io"]
  s.homepage    = "http://www.skylight.io"
  s.summary     = "Skylight is a ruby application monitoring tool."
  s.description = "Currently in pre-alpha."

  s.required_ruby_version = ">= 1.9.2"

  files  = `git ls-files`.split("\n") rescue ''
  files &= Dir['lib/**/*.{rb,pem}']
  files |= Dir['*.md']

  s.files         = files
  s.require_paths = ["lib"]

  # Dependencies
  s.add_dependency('activesupport', '>= 3.0.0')
  s.add_dependency('thor', '~> 0.18.1')
  s.add_dependency('highline', '~> 1.6.18')
  s.add_development_dependency('actionpack', '>= 3.0.0')

  # Executables
  s.executables = %w(skylight)
end
