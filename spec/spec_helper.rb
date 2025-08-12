APP_ROOT = File.expand_path("..", __dir__)

require "rubygems"
require "bundler/setup"

# Do this at the start
coverage = false
if ENV["COVERAGE"]
  begin
    require "simplecov"
    require "simplecov_json_formatter"
    coverage = true
  rescue LoadError
    puts "Skipping CodeClimate coverage reporting"
  end
end

if coverage
  SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
  SimpleCov.start do
    coverage_dir(ENV.fetch("COVERAGE_DIR", "coverage"))
    add_filter %r{/spec/}
    add_filter %r{/vendor/}
  end
end

# Sidekiq 4 added a `Delay` extension to `Module` by default;
# depending on load order, this could conflict with/override Delayed::Job's
# `delay` method. It is disabled by default in Sidekiq 5 and higher.
#
# If Sidekiq.remove_delay! exists, call it, but otherwise don't worry too much about it.
begin
  require "sidekiq"
  require "sidekiq/rails"
  Sidekiq.remove_delay!
rescue Exception # rubocop:disable Lint/SuppressedException
end

require "yaml"
require "beefcake"
require "rspec"
require "rspec/collection_matchers"
require "rack/test"
require "webmock"
require "timecop"

# Loads Skylight + the native extension such that missing the native extension
# will report more helpful errors
require "support/native"

# Support files

module SpecHelper
end

Dir[File.expand_path("support/*.rb", __dir__)].sort.each { |f| require f }

# Begin Probed libraries

def enable_probe(probes, library = probes)
  Array(library).each { |l| require l }
  Skylight::Probes.probe(*probes)
rescue LoadError => e
  puts "Unable to enable #{probes}: #{e}"
end

%w[excon tilt sinatra sequel faraday active_model_serializers httpclient].each { |probe| enable_probe(probe) }

enable_probe(:redis, %w[redis])
enable_probe(:action_view, %w[action_dispatch action_view])
enable_probe(:"action_dispatch/request_id", "action_dispatch/middleware/request_id")
enable_probe(%i[active_job active_job_enqueue], "active_job")
enable_probe(:active_record_async, %w[active_record active_record/future_result])

if ENV["TEST_MONGO_INTEGRATION"]
  enable_probe("mongo")
  enable_probe("mongoid")
end

enable_probe("elasticsearch") if ENV["TEST_ELASTICSEARCH_INTEGRATION"]

require "net/http"
Skylight::Probes.probe(:net_http)

Skylight::Probes.probe(:middleware)

# End Probed Libraries

all_probes = %i[
  excon
  tilt
  sinatra
  sequel
  faraday
  mongo
  mongoid
  httpclient
  elasticsearch
  redis
  action_view
  action_dispatch
  action_dispatch/request_id
  active_job_enqueue
  net_http
  middleware
  active_job
  active_record_async
]

# Check probes that could be installed but don't actually install them
installable_probes =
  Skylight::Probes.registered.select { |_, registration| registration.constant_available? }.map(&:first)
skipped_probes = all_probes - installable_probes

puts "Testing probes: #{installable_probes.join(", ")}" unless installable_probes.empty?
puts "Skipping probes: #{skipped_probes.join(", ")}" unless skipped_probes.empty?

ENV["SKYLIGHT_RAISE_ON_ERROR"] = "true"

unless ENV["SKYLIGHT_DISABLE_AGENT"]
  require "skylight/test"
  Skylight.extend Skylight::Test::Mocking
end

# Similar to above, but this is for waiting for the embedded HTTP server to
# receive requests. The HTTP server is used to mock out the Skylight hosted
# service.
def get_embedded_http_server_timeout
  if (timeout = ENV.fetch("EMBEDDED_HTTP_SERVER_TIMEOUT", nil))
    puts "EMBEDDED_HTTP_SERVER_TIMEOUT=#{timeout}"
    timeout.to_i
  else
    4
  end
end

# Similar to above, but this is for waiting for the worker to spawn.
def get_worker_spawn_timeout
  if (timeout = ENV.fetch("WORKER_SPAWN_TIMEOUT", nil))
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
  config.example_status_persistence_file_path = File.expand_path("../tmp/rspec-examples.txt", __dir__)
  config.color = true

  config.include SpecHelper
  config.include WebMock::API
  config.include WebMock::Matchers

  config.filter_run_excluding agent: true if ENV["SKYLIGHT_DISABLE_AGENT"]

  # Install probes if we're running their specs.
  #   This does limit our abilities to fully test the installation upon Instrumenter start, but we do need
  #   this to be done for the tests to run.
  all_probes.each do |p|
    config.before(:all, "#{p}_probe": true) do
      reg = Skylight::Probes.registered.fetch(p)
      Skylight::Probes.install_probe(reg)
    end
  end

  unless skipped_probes.empty?
    args = {}

    skipped_probes.each { |p| args[:"#{p}_probe"] = true }

    config.filter_run_excluding args
  end

  config.before(:all) do
    if defined?(ActiveJob)
      ActiveJob::Base.logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::FATAL

      ActionMailer::Base.delivery_job = ActionMailer::MailDeliveryJob if defined?(ActionMailer::MailDeliveryJob)
    end

    if defined?(Concurrent) && Concurrent.respond_to?(:global_logger) && !ENV["DEBUG"]
      Concurrent.global_logger = Concurrent::NULL_LOGGER
    end
  end

  config.before do
    Skylight::Probes::Middleware::Probe.instance_exec { @disabled = nil }

    mock_clock!
  end

  config.after :each do
    reset_clock!

    # Reset the starting paths
    Skylight::Probes.instance_variable_set(:@require_hooks, {})

    # Remove the ProbeTestClass if it exists so that the probe won't find it
    SpecHelper.send(:remove_const, :ProbeTestClass) if defined?(SpecHelper::ProbeTestClass)

    SpecHelper.send(:remove_const, :ProbeTestAuxClass) if defined?(SpecHelper::ProbeTestAuxClass)

    Skylight.unmock! if Skylight.respond_to?(:unmock!)

    # Kill any daemon that may have been started
    `pkill -9 skylightd`
  end

  original_wd = Dir.pwd
  original_home = ENV.fetch("HOME", nil)

  config.around :each do |example|
    FileUtils.rm_rf tmp

    begin
      FileUtils.mkdir_p(tmp)

      # Sockfile goes into the "tmp" dir
      FileUtils.mkdir_p(tmp("tmp"))
      Dir.chdir(tmp)
      ENV["HOME"] = tmp.to_s

      example.run
    ensure
      Dir.chdir original_wd
      ENV["HOME"] = original_home
    end
  end

  config.around :each, instrumenter: true do |example|
    mock_clock! # This happens before the before(:each) below
    clock.freeze
    Skylight.mock!
    Skylight.trace("Test") { example.run }
  ensure
    Skylight.stop!
  end

  config.around :each, http: true do |ex|
    start_server
    ex.call
  end

  config.after :all do
    # In Rails 3.2 when ActionController::Base is loaded, Test::Unit is initialized.
    # This avoids it trying to auto-run tests in addition to RSpec.
    Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)
  end
end

