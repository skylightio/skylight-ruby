module Skylight
  module Normalize
    class RenderPartial < RenderNormalizer
      register "render_partial.action_view"

      def normalize
        normalize_render "view.render.template", partial: true
      end
    end
  end
end



