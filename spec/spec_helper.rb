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

  shared_context "normalizer" do
    let(:trace) { Struct.new(:endpoint).new }

    def normalize(*args)
      payload = {}
      payload = args.pop if Hash === args.last
      config = Object.new
      config = args.shift if Struct === args.first

      description = self.class.metadata[:example_group][:description_args]
      name = description[1] ? description[1] : description[0]
      name = args.pop if String === args.last

      Skylight::Normalize.normalize(trace, name, payload, config)
    end
  end

  # Add configuration here

end
