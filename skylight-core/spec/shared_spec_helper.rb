# Require dependencies
require "yaml"
require "beefcake"
require "rspec"
require "rspec/collection_matchers"
require "rack/test"
require "webmock"

module SpecHelper
end

# Require support files
Dir[File.expand_path("support/*.rb", __dir__)].each do |f|
  require f
end

# Begin Probed libraries

if ENV["AMS_VERSION"] == "edge"
  require "active_support/inflector"
end

# rubocop:disable Lint/HandleExceptions

%w[excon tilt sinatra sequel faraday mongo moped mongoid active_model_serializers httpclient elasticsearch].each do |library|
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

all_probes = %w[Excon Faraday Net::HTTP HTTPClient Redis Tilt::Template Sinatra::Base Sequel ActionView::TemplateRenderer ActionDispatch::MiddlewareStack::Middleware]
installed_probes = Skylight::Probes.installed.keys
skipped_probes = all_probes - installed_probes

rspec_probe_tags = {
  "ActionDispatch::MiddlewareStack::Middleware" => "middleware"
}

puts "Testing probes: #{installed_probes.join(', ')}" unless installed_probes.empty?
puts "Skipping probes: #{skipped_probes.join(', ')}"  unless skipped_probes.empty?

ENV["SKYLIGHT_RAISE_ON_ERROR"] = "true"

module TestNamespace
  include Skylight::Instrumentable

  unless ENV["SKYLIGHT_DISABLE_AGENT"]
    require "skylight/core/test"
    extend Skylight::Core::Test::Mocking
  end

  def self.config_class
    Skylight::Config
  end

  class Middleware < Skylight::Core::Middleware
    def instrumentable
      TestNamespace
    end
  end
end

RSpec.configure do |config|
  config.color = true

  config.include WebMock::API
  config.include WebMock::Matchers

  unless defined?(Moped) && defined?(Mongoid)
    config.filter_run_excluding moped: true
  end

  if ENV["SKYLIGHT_DISABLE_AGENT"]
    config.filter_run_excluding agent: true
  end

  e = ENV.clone

  config.before :each do
    Skylight::Config::ENV_TO_KEY.keys.each do |key|
      # TODO: It would be good to test other prefixes as well
      key = "SKYLIGHT_#{key}"
      ENV[key] = e[key]
    end
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
      TestNamespace.mock!
      TestNamespace.trace("Test") { example.run }
    ensure
      TestNamespace.stop!
    end
  end

  unless skipped_probes.empty?
    args = {}

    skipped_probes.each do |p|
      probe_name = rspec_probe_tags[p] || p.downcase.gsub("::", "_")
      args["#{probe_name}_probe".to_sym] = true
    end

    config.filter_run_excluding args
  end

  config.before :each do
    mock_clock!
  end

  config.around :each, http: true do |ex|
    start_server
    ex.call
  end

  config.after :each do
    reset_clock!

    # Reset the starting paths
    Skylight::Probes.instance_variable_set(:@require_hooks, {})

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
    def self.<(_other)
      false
    end
  end
end
