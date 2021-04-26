require "spec_helper"
require "skylight/instrumenter"

module Skylight
  # Doesn't require a running agent, but mocking is turned off when the agent is disabled
  describe "Instrumentation integration", :agent do
    include Rack::Test::Methods

    before do
      Normalizers.register("unmatched.test", Normalizers::Normalizer)

      @called_endpoint = nil
      Skylight.mock! { |trace| @called_endpoint = trace.endpoint }
    end

    after do
      Skylight.stop!
      Normalizers.unregister("unmatched.test")
    end

    def app
      @app ||=
        Rack::Builder.new do
          use Skylight::Middleware
          run lambda { |_env|
                # This will cause the normalizer to return a :skip
                ActiveSupport::Notifications.instrument("unmatched.test") { [200, {}, ["OK"]] }
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
