require "skylight/normalizers/render"

module Skylight
  module Normalizers
    module ActionView
      # Normalizer for Rails collection rendering
      class RenderCollection < RenderNormalizer
        register "render_collection.action_view"

        CAT = "view.render.collection".freeze

        # @param trace [Skylight::Messages::Trace::Builder] ignored, only present to match API
        # @param name [String] ignored, only present to match API
        # @param payload (see RenderNormalizer#normalize_render)
        # @option payload (see RenderNormalizer#normalize_render)
        # @option payload [Integer] :count
        # @return (see RenderNormalizer#normalize_render)
        def normalize(_trace, _name, payload)
          normalize_render(CAT, payload)
        end
      end
    end
  end
end
