# Require dependencies
require 'yaml'
require 'beefcake'
require 'rspec'
require 'rspec/collection_matchers'
require 'rack/test'

module SpecHelper
end

# Require support files
Dir[File.expand_path('../support/*.rb', __FILE__)].each do |f|
  require f
end


# Begin Probed libraries

if ENV['AMS_VERSION'] == 'edge'
  require 'active_support/inflector'
end

%w(excon tilt sinatra sequel grape faraday mongo moped mongoid active_model_serializers httpclient elasticsearch).each do |library|
  begin
    require library
    Skylight::Core::Probes.probe(library)
  rescue LoadError
  end
end

begin
  require 'redis'
  require 'fakeredis/rspec'
  Skylight::Core::Probes.probe(:redis)
rescue LoadError
end

begin
  require 'action_dispatch'
  require 'action_view'
  Skylight::Core::Probes.probe(:action_view)
rescue LoadError
end

require 'net/http'
Skylight::Core::Probes.probe(:net_http)

Skylight::Core::Probes.probe(:middleware)

# End Probed Libraries


all_probes = %w(Excon Faraday Net::HTTP HTTPClient Redis Tilt::Template Sinatra::Base Sequel ActionView::TemplateRenderer ActionDispatch::MiddlewareStack::Middleware)
installed_probes = Skylight::Core::Probes.installed.keys
skipped_probes = all_probes - installed_probes

rspec_probe_tags = {
  "ActionDispatch::MiddlewareStack::Middleware" => "middleware"
}

puts "Testing probes: #{installed_probes.join(", ")}" unless installed_probes.empty?
puts "Skipping probes: #{skipped_probes.join(", ")}"  unless skipped_probes.empty?


ENV['SKYLIGHT_RAISE_ON_ERROR'] = "true"

# TODO: Move elsewhere
module Skylight
  module Test
    module Mocking

      unless ENV['SKYLIGHT_DISABLE_AGENT']
        def mock!(&callback)
          config = Core::Config.new(mock_submission: callback || proc {})

          mock_instrumenter_klass = Class.new(self.instrumenter_class) do
            def self.trace_class
              @trace_class ||= Class.new(super) do
                def self.native_new(start, uuid, endpoint)
                  inst = allocate
                  inst.instance_variable_set(:@start, start)
                  inst
                end

                def mock_spans
                  @mock_spans ||= []
                end

                def native_get_started_at
                  @start
                end

                def native_set_endpoint(*args)
                end

                def native_start_span(time, cat)
                  span = {
                    start: time,
                    cat: cat
                  }
                  mock_spans << span
                  # Return integer like the native method does
                  mock_spans.index(span)
                end

                def native_span_set_title(sp, title)
                  mock_spans[sp][:title] = title
                end

                def native_span_set_description(sp, desc)
                  mock_spans[sp][:desc] = desc
                end

                def native_stop_span(span, time)
                  span = mock_spans[span]
                  span[:duration] = time - span[:start]
                  nil
                end
              end
            end

            def self.native_new(*)
              allocate
            end

            def native_start
              true
            end

            def native_submit_trace(trace)
              config[:mock_submission].call(trace)
            end

            def native_stop
            end

            def limited_description(description)
              description
            end
          end

          @instrumenter = mock_instrumenter_klass.new(config).start!
        end
      end
    end
  end
end

module TestNamespace
  include Skylight::Core::Instrumentable
  extend Skylight::Test::Mocking

  class Middleware < Skylight::Core::Middleware

    def instrumentable
      TestNamespace
    end

  end
end


RSpec.configure do |config|
  config.color = true

  unless defined?(Moped) && defined?(Mongoid)
    config.filter_run_excluding moped: true
  end

  if ENV['SKYLIGHT_DISABLE_AGENT']
    config.filter_run_excluding agent: true
  end

  e = ENV.clone

  config.before :each do
    Skylight::Core::Config.env_to_key.keys.each do |key|
      # TODO: It would be good to test other prefixes as well
      key = "SKYLIGHT_#{key}"
      ENV[key] = e[key]
    end
  end

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
      TestNamespace.mock!
      TestNamespace.trace("Test") { example.run }
    ensure
      TestNamespace.stop!
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

  config.before :each do
    mock_clock!
  end

  config.before :each, http: true do
    start_server
  end

  config.after :each do
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
