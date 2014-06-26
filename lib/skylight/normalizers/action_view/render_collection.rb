module Skylight
  module Normalizers
    class RenderCollection < RenderNormalizer
      register "render_collection.action_view"

      CAT = "view.render.collection".freeze

      def normalize(trace, name, payload)
        normalize_render(
          CAT,
          payload,
          count: payload[:count])
      end
    end
  end
end
