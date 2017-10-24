APP_ROOT = File.expand_path("../..", __FILE__)

require 'rubygems'
require 'bundler/setup'

# Do this at the start
begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  puts "Skipping CodeClimate coverage reporting"
end

require 'timecop'

require 'webmock/rspec'
WebMock.disable!

require 'rack/test'

# Loads Skylight + the native extension such that missing the native extension
# will report more helpful errors
require "support/native"

# Support files

require_relative '../skylight-core/spec/shared_spec_helper'

Dir[File.expand_path('../support/*.rb', __FILE__)].each do |f|
  require f
end

# Similar to above, but this is for waiting for the embedded HTTP server to
# receive requests. The HTTP server is used to mock out the Skylight hosted
# service.
def get_embedded_http_server_timeout
  if timeout = ENV['EMBEDDED_HTTP_SERVER_TIMEOUT']
    puts "EMBEDDED_HTTP_SERVER_TIMEOUT=#{timeout}"
    timeout.to_i
  else
    4
  end
end

# Similar to above, but this is for waiting for the worker to spawn.
def get_worker_spawn_timeout
  if timeout = ENV['WORKER_SPAWN_TIMEOUT']
    puts "WORKER_SPAWN_TIMEOUT=#{timeout}"
    timeout.to_i
  else
    4
  end
end

EMBEDDED_HTTP_SERVER_TIMEOUT = get_embedded_http_server_timeout
WORKER_SPAWN_TIMEOUT = get_worker_spawn_timeout

# End Normalize Libraries

RSpec.configure do |config|
  config.example_status_persistence_file_path = File.expand_path("../../tmp/rspec-examples.txt", __FILE__)

  config.include SpecHelper

  if ENV['SKYLIGHT_DISABLE_AGENT']
    config.filter_run_excluding agent: true
  end

  config.before :each, http: true do
    start_server
  end

  config.after :each do
    cleanup_all_spawned_workers
  end
end
