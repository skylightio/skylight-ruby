require "spec_helper"

begin
  require "rails"
  require "action_controller/railtie"
  require "view_component"
  requirements_loaded = true
rescue LoadError
end

if requirements_loaded
  # The ViewComponent probe needs Rails.application to exist so it can set
  # config.view_component.instrumentation_enabled. Build a minimal app if
  # one hasn't been booted already (e.g. when running this file in isolation).
  unless Rails.application
    module ViewComponentTestApp
      class Application < Rails::Application
        config.eager_load = false
        config.active_support.deprecation = :stderr
        config.secret_key_base = "test-secret"
      end
    end

    ViewComponentTestApp::Application.initialize!
  end

  describe "ViewComponent integration", :view_component_probe, :agent do
    after(:all) do
      if defined?(ViewComponentTestApp)
        Rails.application = nil
        Object.send(:remove_const, :ViewComponentTestApp)
      end
    end

    it "enables instrumentation config" do
      expect(Rails.application.config.view_component.instrumentation_enabled).to be true
    end

    it "prepends the Instrumentation module onto ViewComponent::Base" do
      expect(::ViewComponent::Base.ancestors).to include(::ViewComponent::Instrumentation)
    end

    context "rendering", :instrumenter do
      before do
        stub_const(
          "TestComponent",
          Class.new(::ViewComponent::Base) do
            def call
              "Hello from ViewComponent"
            end
          end
        )
      end

      it "fires a render.view_component AS::N event" do
        events = []
        callback = lambda { |*args| events << ActiveSupport::Notifications::Event.new(*args) }

        ActiveSupport::Notifications.subscribed(callback, "render.view_component") do
          controller = ActionController::Base.new
          request = ActionDispatch::TestRequest.create
          controller.request = request

          component = TestComponent.new
          component.render_in(controller.view_context)
        end

        expect(events).not_to be_empty
        expect(events.first.name).to eq("render.view_component")
      end
    end
  end
end
