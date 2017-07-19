$:.push "#{File.expand_path('..', __FILE__)}/lib"

# Maintain your gem's version:
require "skylight/version"

Gem::Specification.new do |s|
  s.name        = "skylight"
  s.version     = Skylight::VERSION.gsub("-", ".")
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tilde, Inc."]
  s.email       = ["engineering@tilde.io"]
  s.homepage    = "http://www.skylight.io"
  s.summary     = "Skylight is a smart profiler for Rails apps"
  s.license     = "Nonstandard"

  s.required_ruby_version = ">= 1.9.2"

  files  = `git ls-files`.split("\n") rescue []
  files &= (
    Dir['lib/**/*.{rb,pem}'] +
    Dir['ext/**/*.{h,c,rb,yml}'] +
    Dir['*.md'])

  s.files         = files
  s.require_paths = ["lib"]

  # Dependencies
  s.add_dependency('activesupport', '>= 3.0.0')

  # Executables
  s.executables = %w(skylight)

  # Extensions
  s.extensions << "ext/extconf.rb"
end
