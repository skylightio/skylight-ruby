module Skylight
  module Normalize
    class RenderCollection < RenderNormalizer
      register "render_collection.action_view"

      def normalize
        normalize_render "view.render.collection", count: @payload[:count]
      end
    end
  end
end
