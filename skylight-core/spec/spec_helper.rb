require 'rubygems'
require 'bundler/setup'

# Do this at the start
begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  puts "Skipping CodeClimate coverage reporting"
end

require 'webmock/rspec'
WebMock.disable!

require 'skylight/core'

require_relative 'shared_spec_helper'

RSpec.configure do |config|
  config.example_status_persistence_file_path = File.expand_path("../../tmp/rspec-examples.txt", __FILE__)

  config.include SpecHelper
end
