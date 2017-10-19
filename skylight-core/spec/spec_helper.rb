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

# Require dependencies
require 'yaml'
require 'timecop'
require 'beefcake'
require 'rspec'
require 'rspec/collection_matchers'

require 'webmock/rspec'
WebMock.disable!

require 'skylight/core'

# Begin Probed libraries

if ENV['AMS_VERSION'] == 'edge'
  require 'active_support/inflector'
end

%w(excon tilt sinatra sequel grape faraday mongo moped mongoid active_model_serializers httpclient elasticsearch).each do |library|
  begin
    require library
    require "skylight/core/probes/#{library}"
  rescue LoadError
  end
end

begin
  require 'redis'
  require 'fakeredis'
  require 'skylight/core/probes/redis'
rescue LoadError
end

begin
  require 'action_dispatch'
  require 'action_view'
  require 'skylight/core/probes/action_view'
rescue LoadError
end

require 'net/http'
require 'skylight/core/probes/net_http'
require "skylight/core/probes/middleware"

# End Probed Libraries


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

module SpecHelper
end

# Require support files
Dir[File.expand_path('../support/*.rb', __FILE__)].each do |f|
  require "support/#{File.basename(f, ".rb")}"
end

all_probes = %w(Excon Faraday Net::HTTP HTTPClient Redis Tilt::Template Sinatra::Base Sequel ActionView::TemplateRenderer ActionDispatch::MiddlewareStack::Middleware)
installed_probes = Skylight::Core::Probes.installed.keys
skipped_probes = all_probes - installed_probes

puts "Testing probes: #{installed_probes.join(", ")}" unless installed_probes.empty?
puts "Skipping probes: #{skipped_probes.join(", ")}"  unless skipped_probes.empty?


ENV['SKYLIGHT_RAISE_ON_ERROR'] = "true"


rspec_probe_tags = {
  "ActionDispatch::MiddlewareStack::Middleware" => "middleware"
}

RSpec.configure do |config|
  config.color = true

  config.example_status_persistence_file_path = File.expand_path("../../tmp/rspec-examples.txt", __FILE__)

  unless defined?(Moped) && defined?(Mongoid)
    config.filter_run_excluding moped: true
  end

  e = ENV.clone

  config.before :each do
    Skylight::Core::Config::ENV_TO_KEY.keys.each do |key|
      key = "SKYLIGHT_#{key}"
      ENV[key] = e[key]
    end
  end

  unless skipped_probes.empty?
    args = {}

    skipped_probes.each do |p|
      probe_name = rspec_probe_tags[p] || p.downcase.gsub('::', '_')
      args["#{probe_name}_probe".to_sym] = true
    end

    config.filter_run_excluding args
  end

  config.include SpecHelper

  original_wd   = Dir.pwd
  original_home = ENV['HOME']

  config.around :each do |example|
    if File.exist?(tmp)
      FileUtils.rm_rf tmp
    end

    begin
      FileUtils.mkdir_p(tmp)
      # Sockfile goes into the "tmp" dir
      FileUtils.mkdir_p(tmp("tmp"))
      Dir.chdir(tmp)
      ENV['HOME'] = tmp.to_s

      example.run
    ensure
      Dir.chdir original_wd
      ENV['HOME'] = original_home
    end
  end

  config.around :each, instrumenter: true do |example|
    begin
      mock_clock! # This happens before the before(:each) below
      clock.freeze
      Skylight::Core::Instrumenter.mock!
      Skylight.trace("Test") { example.run }
    ensure
      Skylight::Core::Instrumenter.stop!
    end
  end

  config.before :each do
    mock_clock!
  end

  config.before :each, http: true do
    start_server
  end

  config.after :each do
    cleanup_all_spawned_workers
    reset_clock!

    # Reset the starting paths
    Skylight::Core::Probes.instance_variable_set(:@require_hooks, {})

    # Remove the ProbeTestClass if it exists so that the probe won't find it
    if defined?(SpecHelper::ProbeTestClass)
      SpecHelper.send(:remove_const, :ProbeTestClass)
    end
  end

  config.after :all do
    # In Rails 3.2 when ActionController::Base is loaded, Test::Unit is initialized.
    # This avoids it trying to auto-run tests in addition to RSpec.
    if defined?(Test::Unit::AutoRunner)
      Test::Unit::AutoRunner.need_auto_run = false
    end
  end

end

# FIXME: Review this
if defined?(Axiom::Types::Infinity)
  # Old versions of axiom-types don't play well with newer RSpec
  class Axiom::Types::Infinity
    def self.<(other)
      false
    end
  end
end
