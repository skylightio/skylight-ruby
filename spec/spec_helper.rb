require 'spec_helper'

require 'rspec'
require 'skylight'

Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|
  config.include SpecHelper::Path

  original_wd = Dir.pwd

  config.before :each do
    FileUtils.rm_rf tmp
  end

  config.after :each do
    Dir.chdir(original_wd)
  end

end
