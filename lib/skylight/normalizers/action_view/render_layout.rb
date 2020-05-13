# frozen_string_literal: true

require "skylight/normalizers/render"

module Skylight
  module Normalizers
    module ActionView
      # Normalizer for Rails layout rendering
      class RenderLayout < RenderNormalizer
        register "render_layout.action_view"

        CAT = "view.render.layout"

        # @param trace [Skylight::Messages::Trace::Builder] ignored, only present to match API
        # @param name [String] ignored, only present to match API
        # @param payload (see RenderNormalizer#normalize_render)
        # @option payload (see RenderNormalizer#normalize_render)
        # @return (see RenderNormalizer#normalize_render)
        def normalize(_trace, _name, payload)
          normalize_render(CAT, payload)
        end
      end
    end
  end
end
