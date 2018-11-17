# coding: utf-8
version = File.read(File.expand_path("../../SKYLIGHT_VERSION", __FILE__)).strip.tr("-", ".")

Gem::Specification.new do |spec|
  spec.name        = "skylight-core"
  spec.version     = version
  spec.authors     = ["Tilde, Inc."]
  spec.email       = ["engineering@tilde.io"]

  spec.summary     = "The core methods of the Skylight profiler."
  spec.homepage    = "https://www.skylight.io"
  spec.license     = "Nonstandard"

  spec.required_ruby_version = ">= 2.2.7"

  files = `git ls-files`.split("\n") rescue []
  files &= (
    Dir["lib/**/*.rb"] +
    Dir["*.md"])

  spec.files         = files
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 4.2.0"

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.1"
  spec.add_development_dependency "beefcake", "< 1.0"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "rack-test"
end
