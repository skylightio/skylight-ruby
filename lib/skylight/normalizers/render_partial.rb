module Skylight
  module Normalizers
    class RenderPartial < RenderNormalizer
      register "render_partial.action_view"

      def normalize(trace, name, payload)
        normalize_render(
          "view.render.template",
          payload,
          partial: 1)
      end
    end
  end
end
