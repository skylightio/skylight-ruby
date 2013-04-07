module Skylight
  module Normalize
    class RenderPartial < Normalizer
      register "render_partial.action_view"

      def normalize
        path = @payload[:identifier]
        annotations = { partial: true }

        [ "view.render.template", path, path, annotations ]
      end
    end
  end
end



