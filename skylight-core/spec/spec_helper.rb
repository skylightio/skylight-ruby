require "rubygems"
require "bundler/setup"

# Do this at the start
begin
  require "simplecov"
  SimpleCov.start do
    coverage_dir(ENV["COVERAGE_DIR"] || "coverage")
    add_filter %r{/spec/}
    add_filter %r{/vendor/}
  end
rescue LoadError
  puts "Skipping CodeClimate coverage reporting"
end

require "skylight/core"

require_relative "shared_spec_helper"

RSpec.configure do |config|
  config.example_status_persistence_file_path = File.expand_path("../tmp/rspec-examples.txt", __dir__)

  config.include SpecHelper
end
