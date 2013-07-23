module Skylight
  module Normalizers
    class RenderCollection < RenderNormalizer
      register "render_collection.action_view"

      def normalize(trace, name, payload)
        normalize_render(
          "view.render.collection",
          payload,
          count: payload[:count])
      end
    end
  end
end
