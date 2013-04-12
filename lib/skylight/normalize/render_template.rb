module Skylight
  module Normalize
    class RenderTemplate < Normalizer
      register "render_template.action_view"

      def normalize
        path = @payload[:identifier]
        annotations = { partial: false }

        [ "view.render.template", path, nil, annotations ]
      end
    end
  end
end


