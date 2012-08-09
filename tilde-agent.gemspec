Gem::Specification.new do |s|
  s.name        = "tilde-agent"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tilde, Inc."]
  s.email       = ["info@tilde.io"]
  s.homepage    = "http://www.tilde.io"
  s.summary     = "Don't ship blind"
  s.description = "It's awesome"

  s.required_ruby_version = ">= 1.8.7"

  s.require_paths = ["lib"]

  # Dependencies
  s.add_dependency('activesupport', '>= 3.0.0')
end
