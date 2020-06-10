# frozen_string_literal: true

module Skylight
  module Probes
    module ActionView
      module Instrumentation
        def render_with_layout(*args) #:nodoc:
          path, locals = case args.length
                         when 2
                           args
                         when 4
                           # Rails > 6.0.0.beta3 arguments are (view, template, path, locals)
                           [args[2], args[3]]
                         end

          layout = nil

          if path
            layout = find_layout(path, locals.keys, [formats.first])
          end

          if layout
            ActiveSupport::Notifications.instrument("render_template.action_view", identifier: layout.identifier) do
              super
            end
          else
            super
          end
        end
      end

      class Probe
        def install
          return if ::ActionView.gem_version >= Gem::Version.new("6.1.0.alpha")

          ::ActionView::TemplateRenderer.prepend(Instrumentation)
        end
      end
    end

    register(:action_view, "ActionView::TemplateRenderer", "action_view", ActionView::Probe.new)
  end
end
