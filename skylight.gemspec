$LOAD_PATH.push(File.expand_path("lib", __dir__))
require "skylight/version"

Gem::Specification.new do |spec|
  spec.name = "skylight"
  spec.version = Skylight::VERSION.tr("-", ".")
  spec.authors = ["Tilde, Inc."]
  spec.email = ["engineering@tilde.io"]

  spec.summary =
    "Skylight is a smart profiler for Rails, Sinatra, and other Ruby apps."
  spec.homepage = "https://www.skylight.io"
  spec.license = "Nonstandard"

  spec.required_ruby_version = ">= 3.1"

  files =
    begin
      `git ls-files`.split("\n")
    rescue StandardError
      []
    end
  files &=
    (Dir["lib/**/*.{rb,pem}"] + Dir["ext/**/*.{h,c,rb,yml}"] + Dir["*.md"])

  spec.files = files
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "activesupport", ">= 7.2.0"

  spec.add_development_dependency "beefcake", "~> 1.0"
  spec.add_development_dependency "bundler", ">= 1.17.3"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.1"
  spec.add_development_dependency "rubocop", "~> 1.86.2"
  spec.add_development_dependency "simplecov", "~> 0.21.2"
  spec.add_development_dependency "syntax_tree"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "webmock"
  # ostruct is not directly required, but it is commonly omitted by third-party
  # libraries we load in tests, and is no longer included with ruby 4.
  spec.add_development_dependency "ostruct"

  # Executables
  spec.executables = %w[skylight]

  # Extensions
  spec.extensions << "ext/extconf.rb"
  spec.metadata = { "rubygems_mfa_required" => "true" }
end
