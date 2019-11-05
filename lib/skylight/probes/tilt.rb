# Should support 0.2+, though not tested against older versions
module Skylight
  module Probes
    module Tilt
      class Probe
        def install
          ::Tilt::Template.class_eval do
            alias_method :render_without_sk, :render

            def render(*args, &block)
              opts = {
                category: "view.render.template",
                title: options[:sky_virtual_path] || basename || "Unknown template name"
              }

              Skylight.instrument(opts) do
                render_without_sk(*args, &block)
              end
            end
          end
        end
      end
    end

    register(:tilt, "Tilt::Template", "tilt/template", Tilt::Probe.new)
  end
end
