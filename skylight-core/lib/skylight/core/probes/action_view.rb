module Skylight::Core
  module Probes
    module ActionView
      class Probe
        def install
          ::ActionView::TemplateRenderer.class_eval do
            alias_method :render_with_layout_without_sk, :render_with_layout

            def render_with_layout(*args, &block) #:nodoc:
              path, locals = case args.length
                             when 2
                               args
                             when 4
                               # Rails >= 6.0.0.beta2 arguments are (view, path, template, locals)
                               [args[1], args[3]]
                             end

              layout = nil

              if path
                layout =
                  if ::ActionView::VERSION::MAJOR >= 5
                    find_layout(path, locals.keys, [formats.first])
                  else
                    find_layout(path, locals.keys)
                  end
              end

              if layout
                instrument(:template, identifier: layout.identifier) do
                  render_with_layout_without_sk(*args, &block)
                end
              else
                render_with_layout_without_sk(*args, &block)
              end
            end
          end
        end
      end
    end

    register(:action_view, "ActionView::TemplateRenderer", "action_view", ActionView::Probe.new)
  end
end
