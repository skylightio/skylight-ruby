module Skylight
  module Normalizers
    class RenderTemplate < RenderNormalizer
      register "render_template.action_view"

      def normalize(trace, name, payload)
        normalize_render(
          "view.render.template",
          payload,
          partial: 0)
      end
    end
  end
end
