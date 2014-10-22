APP_ROOT = File.expand_path("../..", __FILE__)

require 'rubygems'
require 'bundler/setup'

# Require dependencies
require 'yaml'
require 'timecop'
require 'beefcake'
require 'rspec'
require 'rspec/collection_matchers'

require 'webmock/rspec'
WebMock.disable!

# Loads Skylight + the native extension such that missing the native extension
# will report more helpful errors
require "support/native"

# Begin Probed libraries
begin
  require 'excon'
  require 'skylight/probes/excon'

  require 'redis'
  require 'fakeredis'
  require 'skylight/probes/redis'
rescue LoadError
end

require 'net/http'
require 'skylight/probes/net_http'

# End Probed Libraries


# Begin Normalize Libraries

begin
  require 'moped'
rescue LoadError
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

# Require support files
Dir[File.expand_path('../support/*.rb', __FILE__)].each do |f|
  require "support/#{File.basename(f, ".rb")}"
end

all_probes = %w(Excon Net::HTTP Redis)
installed_probes = Skylight::Probes.installed.keys
skipped_probes = all_probes - installed_probes

puts "Testing probes: #{installed_probes.join(", ")}" unless installed_probes.empty?
puts "Skipping probes: #{skipped_probes.join(", ")}"  unless skipped_probes.empty?

RSpec.configure do |config|
  config.color = true

  unless defined?(Moped)
    config.filter_run_excluding moped: true
  end

  e = ENV.clone

  config.before :each do
    Skylight::Config::ENV_TO_KEY.keys.each do |key|
      key = "SKYLIGHT_#{key}"
      ENV[key] = e[key]
    end
  end

  if ENV['SKYLIGHT_DISABLE_AGENT']
    config.filter_run_excluding agent: true
  end

  unless skipped_probes.empty?
    args = {}

    skipped_probes.each do |p|
      probe_name = p.downcase.gsub('::', '_')
      args["#{probe_name}_probe".to_sym] = true
    end

    config.filter_run_excluding args
  end

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.include SpecHelper

  original_wd   = Dir.pwd
  original_home = ENV['HOME']

  config.around :each do |example|
    if File.exist?(tmp)
      FileUtils.rm_rf tmp
    end

    begin
      FileUtils.mkdir_p(tmp)
      Dir.chdir(tmp)
      ENV['HOME'] = tmp.to_s

      example.run
    ensure
      Dir.chdir original_wd
      ENV['HOME'] = original_home
    end
  end

  config.before :each do
    Skylight::Util::Clock.default = SpecHelper::TestClock.new
  end

  config.before :each, http: true do
    start_server
  end

  config.after :each do
    cleanup_all_spawned_workers

    # Reset the starting paths
    Skylight::Probes.instance_variable_set(:@require_hooks, {})

    # Remove the ProbeTestClass if it exists so that the probe won't find it
    if defined?(SpecHelper::ProbeTestClass)
      SpecHelper.send(:remove_const, :ProbeTestClass)
    end
  end

end
