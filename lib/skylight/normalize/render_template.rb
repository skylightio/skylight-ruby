module Skylight
  module Normalize
    class RenderTemplate < RenderNormalizer
      register "render_template.action_view"

      def normalize
        normalize_render "view.render.template", partial: false
      end
    end
  end
end


