$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "skylight/version"

Gem::Specification.new do |s|
  s.name        = "skylight-agent"
  s.version     = Skylight::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tilde, Inc."]
  s.email       = ["engineering@tilde.io"]
  s.homepage    = "http://www.skylight.io"
  s.summary     = ""
  s.description = ""

  s.required_ruby_version = ">= 1.8.7"

  s.require_paths = ["lib"]

  # Dependencies
  s.add_dependency('activesupport', '>= 3.0.0')
end
