version = File.read(File.expand_path("SKYLIGHT_VERSION", __dir__)).strip.tr("-", ".")

Gem::Specification.new do |spec|
  spec.name        = "skylight"
  spec.version     = version
  spec.authors     = ["Tilde, Inc."]
  spec.email       = ["engineering@tilde.io"]

  spec.summary     = "Skylight is a smart profiler for Rails, Sinatra, and other Ruby apps."
  spec.homepage    = "https://www.skylight.io"
  spec.license     = "Nonstandard"

  spec.required_ruby_version = ">= 2.2.7"

  files = `git ls-files`.split("\n") rescue []
  files &= (
    Dir["lib/**/*.{rb,pem}"] +
    Dir["ext/**/*.{h,c,rb,yml}"] +
    Dir["*.md"])
  files -= Dir["skylight-core"]

  spec.files         = files
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "skylight-core", version

  spec.add_development_dependency "beefcake", "< 1.0"
  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rake-compiler", "~> 1.0.4"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.1"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "webmock"

  # Executables
  spec.executables = %w[skylight]

  # Extensions
  spec.extensions << "ext/extconf.rb"
end
