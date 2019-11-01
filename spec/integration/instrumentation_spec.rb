require "spec_helper"
require "skylight/instrumenter"

module Skylight
  # Doesn't require a running agent, but mocking is turned off when the agent is disabled
  describe "Instrumentation integration", :agent do
    include Rack::Test::Methods

    before do
      Core::Normalizers.register("unmatched.test", Core::Normalizers::Normalizer)

      @called_endpoint = nil
      TestNamespace.mock! do |trace|
        @called_endpoint = trace.endpoint
      end
    end

    after do
      TestNamespace.stop!
      Core::Normalizers.unregister("unmatched.test")
    end

    def app
      @app ||= Rack::Builder.new do
        use TestNamespace::Middleware
        run lambda { |_env|
          # This will cause the normalizer to return a :skip
          ActiveSupport::Notifications.instrument("unmatched.test") do
            [200, {}, ["OK"]]
          end
        }
      end
    end

    it "it handles a :skip" do
      expect_any_instance_of(Core::Subscriber).not_to receive(:error)

      get "/"

      expect(last_response.body).to eq("OK")
      expect(@called_endpoint).to eq("Rack")
    end
  end
end
