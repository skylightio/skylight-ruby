require 'spec_helper'

begin
  require 'skylight/railtie'

  describe Skylight::Railtie do

    it 'has tests'

  end
rescue LoadError
  puts "[INFO] Skipping Skylight::Railtie tests"
end
