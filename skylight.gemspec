$LOAD_PATH.push(File.expand_path("lib", __dir__))
require "skylight/version"

Gem::Specification.new do |spec|
  spec.name        = "skylight"
  spec.version     = Skylight::VERSION.tr("-", ".")
  spec.authors     = ["Tilde, Inc."]
  spec.email       = ["engineering@tilde.io"]

  spec.summary     = "Skylight is a smart profiler for Rails, Sinatra, and other Ruby apps."
  spec.homepage    = "https://www.skylight.io"
  spec.license     = "Nonstandard"

  spec.required_ruby_version = ">= 2.4"

  files = `git ls-files`.split("\n") rescue []
  files &= (
    Dir["lib/**/*.{rb,pem}"] +
    Dir["ext/**/*.{h,c,rb,yml}"] +
    Dir["*.md"])

  spec.files         = files
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "activesupport", ">= 5.2.0"

  spec.add_development_dependency "beefcake", "~> 1.0"
  spec.add_development_dependency "bundler", ">= 1.17.3"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake", "~> 12.3.3"
  spec.add_development_dependency "rake-compiler", "~> 1.0.4"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.1"
  spec.add_development_dependency "rubocop", "~> 0.79.0"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "webmock"

  # Executables
  spec.executables = %w[skylight]

  # Extensions
  spec.extensions << "ext/extconf.rb"
end
