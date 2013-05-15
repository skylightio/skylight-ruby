require 'spec_helper'

require 'rspec'
require 'skylight'

Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|
  config.include SpecHelper

  original_wd = Dir.pwd

  config.before :each do
    if File.exist?(tmp)
      FileUtils.rm_rf tmp
    end
  end

  config.after :each do
    begin
      cleanup_all_spawned_workers
    ensure
      Dir.chdir(original_wd)
    end
  end

end
