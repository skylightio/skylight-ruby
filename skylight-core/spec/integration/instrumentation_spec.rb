require 'spec_helper'
require 'skylight/core/instrumenter'

# Here because we need the agent
module Skylight::Core
  describe 'Instrumentation integration', :agent do
    include Rack::Test::Methods

    before do
      @called_endpoint = nil
      TestNamespace.mock! do |trace|
        @called_endpoint = trace.endpoint
      end
    end

    after do
      TestNamespace.stop!
    end

    def app
      @app ||= Rack::Builder.new do
        use TestNamespace::Middleware
        run lambda { |env|
          # This will cause the normalizer to return a :skip
          ActiveSupport::Notifications.instrument("unmatched.test") do
            [200, {}, ['OK']]
          end
        }
      end
    end

    it "it handles a :skip" do
      expect_any_instance_of(Subscriber).not_to receive(:error)

      get "/"

      expect(last_response.body).to eq("OK")
      expect(@called_endpoint).to eq("Rack")
    end
  end
end
