require 'spec_helper'

begin
  require 'allocation_counter/rspec'
rescue LoadError
end

require 'rspec'
require 'yaml'
require 'skylight'

Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|
  unless defined?(AllocationCounter)
    config.filter_run_excluding allocations: true
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

end
