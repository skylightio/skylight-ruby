module Skylight
  module Normalizers
    module ActionView
      class RenderPartial < RenderNormalizer
        register "render_partial.action_view"

        CAT = "view.render.template".freeze

        def normalize(trace, name, payload)
          normalize_render(CAT, payload)
        end
      end
    end
  end
end
