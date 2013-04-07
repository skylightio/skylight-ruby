module Skylight
  module Normalize
    class RenderCollection < Normalizer
      register "render_collection.action_view"

      def normalize
        path = @payload[:identifier]
        annotations = { count: @payload[:count] }

        [ "view.render.collection", path, path, annotations ]
      end
    end
  end
end

