require "spec_helper"

if defined?(ActionDispatch)

  describe "ActionDispatch::RequestId integration", :'action_dispatch/request_id_probe', :agent do

    before do
      TestNamespace.mock!
    end

    after do
      TestNamespace.stop!
    end

    def build_middleware
      Class.new(Skylight::Core::Middleware) do
        def instrumentable
          TestNamespace
        end
      end
    end

    it "uses skylight.request_id" do
      final_env = nil
      middleware = build_middleware

      app = Rack::Builder.new do
        use middleware
        use ActionDispatch::RequestId
        run lambda { |env| final_env = env; [200, {}, ["OK"]] }
      end

      env = Rack::MockRequest.env_for("/")
      app.call(env)

      expect(final_env["skylight.request_id"]).to_not be_nil
      expect(final_env["action_dispatch.request_id"]).to eq(final_env["skylight.request_id"])
    end

    it "generates own without skylight.request_id" do
      final_env = nil

      app = Rack::Builder.new do
        use ActionDispatch::RequestId
        run lambda { |env| final_env = env; [200, {}, ["OK"]] }
      end

      env = Rack::MockRequest.env_for("/")
      app.call(env)

      expect(final_env["action_dispatch.request_id"]).to_not be_nil
    end

  end
end
