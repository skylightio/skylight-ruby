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

      name = self.class.metadata[:example_group][:description_args][1]
      name = args.pop if String === args.last

      Skylight::Normalize.normalize(trace, name, payload)
    end
  end

  # Add configuration here

end
