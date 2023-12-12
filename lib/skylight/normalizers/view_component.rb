require "skylight/normalizers/render"

module Skylight
  module Normalizers
    class ViewComponent < RenderNormalizer
      register "render.view_component"

      CAT = "view.render.component"

      def normalize(_trace, _name, payload)
        res = normalize_render(CAT, payload)
        res
      end
    end
  end
end
