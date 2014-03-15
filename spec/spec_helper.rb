require 'rubygems'
require 'bundler/setup'

require 'rspec'

# Trigger hard-crash if C-ext is missing
ENV["SKYLIGHT_REQUIRED"] = "true"

require 'yaml'
require 'skylight'
require 'timecop'
require 'beefcake'

# Begin Probed libraries

begin
  require 'excon'
  require 'skylight/probes/excon'
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

# The standalone worker specs require waiting for subprocesses to do work. It
# would be quite difficult to coordinate a mocked clock, so we just wait for
# the work to happen and timeout if it doesn't. Unfortunetly, this can cause
# specs to fail when run in low resource situations (aka, travis). In those
# cases, we should significantly increase the timeout.
def get_standalone_worker_spec_timeout
  if timeout = ENV['STANDALONE_WORKER_SPEC_TIMEOUT']
    puts "STANDALONE_WORKER_SPEC_TIMEOUT=#{timeout}"
    timeout.to_i
  else
    10
  end
end

# Similar to above, but this is for waiting for the embedded HTTP server to
# receive requests. The HTTP server is used to mock out the Skylight hosted
# service.
def get_embedded_http_server_timeout
  if timeout = ENV['EMBEDDED_HTTP_SERVER_TIMEOUT']
    puts "EMBEDDED_HTTP_SERVER_TIMEOUT=#{timeout}"
    timeout.to_i
    timeout.to_i
  else
    4
  end
end

STANDALONE_WORKER_SPEC_TIMEOUT = get_standalone_worker_spec_timeout
EMBEDDED_HTTP_SERVER_TIMEOUT = get_embedded_http_server_timeout

# End Normalize Libraries

Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }

all_probes = %w(Excon Net::HTTP)
installed_probes = Skylight::Probes.installed.keys
skipped_probes = all_probes - installed_probes

puts "Testing probes: #{installed_probes.join(", ")}" unless installed_probes.empty?
puts "Skipping probes: #{skipped_probes.join(", ")}"  unless skipped_probes.empty?

RSpec.configure do |config|
  unless defined?(AllocationCounter)
    config.filter_run_excluding allocations: true
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

  config.before :each do
    Skylight::Util::Clock.default = SpecHelper::TestClock.new

    if File.exist?(tmp)
      FileUtils.rm_rf tmp
    end

    FileUtils.mkdir_p(tmp)
    Dir.chdir(tmp)
    ENV['HOME'] = tmp.to_s
  end

  config.before :each, http: true do
    start_server
  end

  config.after :each do
    begin
      cleanup_all_spawned_workers
    ensure
      Dir.chdir original_wd
      ENV['HOME'] = original_home
    end
  end

  config.after :each do
    # Reset the starting paths
    Skylight::Probes.instance_variable_set(:@require_hooks, {})

    # Remove the ProbeTestClass if it exists so that the probe won't find it
    if defined?(SpecHelper::ProbeTestClass)
      SpecHelper.send(:remove_const, :ProbeTestClass)
    end
  end

end
