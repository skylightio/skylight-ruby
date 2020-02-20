APP_ROOT = File.expand_path("..", __dir__)

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

Dir[File.expand_path("support/*.rb", __dir__)].each do |f|
  require f
end

# Begin Probed libraries

if ENV["AMS_VERSION"] == "edge"
  require "active_support/inflector"
end

# rubocop:disable Lint/HandleExceptions

%w[excon tilt sinatra sequel faraday mongo mongoid active_model_serializers
   httpclient elasticsearch].each do |library|
  begin
    require library
    Skylight::Probes.probe(library)
  rescue LoadError
    puts "Unable to load #{library}"
  end
end

begin
  require "redis"
  require "fakeredis/rspec"
  Skylight::Probes.probe(:redis)
rescue LoadError
end

begin
  require "action_dispatch"
  require "action_view"
  Skylight::Probes.probe(:action_view)
rescue LoadError
end

begin
  require "action_dispatch/middleware/request_id"
  Skylight::Probes.probe(:'action_dispatch/request_id')
rescue LoadError
end

begin
  require "active_job"
  Skylight::Probes.probe(:active_job_enqueue)
rescue LoadError
end

# rubocop:enable Lint/HandleExceptions

require "net/http"
Skylight::Probes.probe(:net_http)

Skylight::Probes.probe(:middleware)

# End Probed Libraries

all_probes = %w[Excon Faraday Net::HTTP HTTPClient Redis Tilt::Template Sinatra::Base Sequel
                ActionView::TemplateRenderer ActionDispatch::MiddlewareStack::Middleware]
installed_probes = Skylight::Probes.installed.keys
skipped_probes = all_probes - installed_probes

rspec_probe_tags = {
  "ActionDispatch::MiddlewareStack::Middleware" => "middleware"
}

puts "Testing probes: #{installed_probes.join(', ')}" unless installed_probes.empty?
puts "Skipping probes: #{skipped_probes.join(', ')}"  unless skipped_probes.empty?

ENV["SKYLIGHT_RAISE_ON_ERROR"] = "true"

unless ENV["SKYLIGHT_DISABLE_AGENT"]
  require "skylight/test"
  Skylight.extend Skylight::Test::Mocking
end

# Similar to above, but this is for waiting for the embedded HTTP server to
# receive requests. The HTTP server is used to mock out the Skylight hosted
# service.
def get_embedded_http_server_timeout
  if (timeout = ENV["EMBEDDED_HTTP_SERVER_TIMEOUT"])
    puts "EMBEDDED_HTTP_SERVER_TIMEOUT=#{timeout}"
    timeout.to_i
  else
    4
  end
end

# Similar to above, but this is for waiting for the worker to spawn.
def get_worker_spawn_timeout
  if (timeout = ENV["WORKER_SPAWN_TIMEOUT"])
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

  if ENV["SKYLIGHT_DISABLE_AGENT"]
    config.filter_run_excluding agent: true
  end

  unless skipped_probes.empty?
    args = {}

    skipped_probes.each do |p|
      probe_name = rspec_probe_tags[p] || p.downcase.gsub("::", "_")
      args["#{probe_name}_probe".to_sym] = true
    end

    config.filter_run_excluding args
  end

  e = ENV.clone

  config.before(:all) do
    if defined?(ActiveJob)
      ActiveJob::Base.logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::FATAL

      if defined?(ActionMailer::MailDeliveryJob)
        ActionMailer::Base.delivery_job = ActionMailer::MailDeliveryJob
      end
    end

    if defined?(Concurrent) && Concurrent.respond_to?(:global_logger) && !ENV["DEBUG"]
      Concurrent.global_logger = Concurrent::NULL_LOGGER
    end
  end

  config.before do
    Skylight::Config::ENV_TO_KEY.keys.each do |key|
      # TODO: It would be good to test other prefixes as well
      key = "SKYLIGHT_#{key}"
      ENV[key] = e[key]
    end

    Skylight::Probes::Middleware::Probe.instance_exec { @disabled = nil }

    mock_clock!
  end

  config.after :each do
    reset_clock!

    # Reset the starting paths
    Skylight::Probes.instance_variable_set(:@require_hooks, {})

    # Remove the ProbeTestClass if it exists so that the probe won't find it
    if defined?(SpecHelper::ProbeTestClass)
      SpecHelper.send(:remove_const, :ProbeTestClass)
    end

    Skylight.unmock! if Skylight.respond_to?(:unmock!)

    # Kill any daemon that may have been started
    `pkill -9 skylightd`
  end

  original_wd   = Dir.pwd
  original_home = ENV["HOME"]

  config.around :each do |example|
    if File.exist?(tmp)
      FileUtils.rm_rf tmp
    end

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
    begin
      mock_clock! # This happens before the before(:each) below
      clock.freeze
      Skylight.mock!
      Skylight.trace("Test") { example.run }
    ensure
      Skylight.stop!
    end
  end

  config.around :each, http: true do |ex|
    start_server
    ex.call
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
    def self.<(_other)
      false
    end
  end
end
