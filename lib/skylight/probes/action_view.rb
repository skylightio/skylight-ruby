module Skylight
  module Probes
    module ActionView
      class Probe
        def install
          # Rails 3.0 didn't have ActionView::TemplateRenderer, but it also
          # didn't have the bug that this probe is trying to fix. In Rails
          # 3.1, a templating engine refactor moved the layout rendering out
          # of the existing instrumentation, making any other events that
          # happen inside of the layout appear to happen directly inside the
          # parent (usually the controller).
          return if [ActionPack::VERSION::MAJOR, ActionPack::VERSION::MINOR] == [3, 0]

          ::ActionView::TemplateRenderer.class_eval do
            alias render_with_layout_without_sk render_with_layout

            def render_with_layout(path, locals, *args, &block) #:nodoc:
              layout  = path && find_layout(path, locals.keys)

              if layout
                instrument(:template, :identifier => layout.identifier) do
                  render_with_layout_without_sk(path, locals, *args, &block)
                end
              else
                render_with_layout_without_sk(path, locals, *args, &block)
              end
            end
          end
        end
      end
    end

    register("ActionView::TemplateRenderer", "action_view", ActionView::Probe.new)
  end
end
