ENV['RAILS_ENV'] = 'production'

require 'rspec'
require 'rails'
require 'skylight'
require 'capybara/rspec'
require 'rack/test'
require 'webmock/rspec'

require 'dummy/config/environment.rb'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

WebMock.disable_net_connect!

RSpec.configure do |config|

  config.include SpecHelpers

  # Add configuration here
  config.before :all do
    Skylight::Excon.defaults[:mock] = true
  end

  config.before :each do
    Skylight::Excon.stubs.clear
  end

end
