require 'rspec'
require 'skylight'
require 'capybara/rspec'
require 'rack/test'

require 'dummy/config/environment.rb'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|

  # Add configuration here

end
