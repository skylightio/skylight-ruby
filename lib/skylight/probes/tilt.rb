# Should support 0.2+, though not tested against older versions
module Skylight
  module Probes
    module Tilt
      module Instrumentation
        def render(*args, &block)
          opts = {
            category: "view.render.template",
            title: options[:sky_virtual_path] || basename || "Unknown template name"
          }

          Skylight.instrument(opts) { super(*args, &block) }
        end
      end

      class Probe
        def install
          ::Tilt::Template.prepend(Instrumentation)
        end
      end
    end

    register(:tilt, "Tilt::Template", "tilt/template", Tilt::Probe.new)
  end
end
