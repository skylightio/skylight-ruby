module Skylight
  module Probes
    module ViewComponent
      class Probe
        def install
          version = Gem.loaded_specs["view_component"]&.version

          if !version || version < Gem::Version.new("3.0.0")
            Skylight.error "Instrumentation is only available for ViewComponent version 3.0.0 and greater."
            return
          end

          unless defined?(Rails) && Rails.application
            Skylight.error "ViewComponent instrumentation requires a Rails application."
            return
          end

          Rails.application.config.view_component.instrumentation_enabled = true

          # ViewComponent 3.x defaults to the "!" prefix for notification names
          # (e.g., "!render.view_component"), which is an internal AS::N event
          # that our subscriber can't see. Disable this so the standard
          # "render.view_component" event is emitted instead.
          if ::ViewComponent::Base.config.respond_to?(:use_deprecated_instrumentation_name)
            ::ViewComponent::Base.config.use_deprecated_instrumentation_name = false
          end

          # Ensure the Instrumentation module is loaded — it lives in a
          # separate file that may not have been autoloaded yet.
          require "view_component/instrumentation"

          # If the engine initializer has already run, we need to prepend the
          # instrumentation module ourselves. The runtime guard inside
          # ViewComponent::Instrumentation#render_in checks the config flag,
          # which we've already set above.
          unless ::ViewComponent::Base.ancestors.include?(::ViewComponent::Instrumentation)
            ::ViewComponent::Base.prepend(::ViewComponent::Instrumentation)
          end
        end
      end
    end

    register(:view_component, "ViewComponent::Base", "view_component", ViewComponent::Probe.new)
  end
end
