module Skylight
  module Normalizers
    class RenderTemplate < RenderNormalizer
      register "render_template.action_view"

      CAT = "view.render.template".freeze

      def normalize(trace, name, payload)
        normalize_render(
          CAT,
          payload,
          partial: 0)
      end
    end
  end
end
