# frozen_string_literal: true

module Skylight::Core
  module Normalizers
    module Graphiti
      class Render < Normalizer
        register "render.graphiti"

        CAT = "view.render.graphiti"
        ANONYMOUS = "<Anonymous Resource>"

        def normalize(_trace, _name, payload)
          resource_class = payload[:proxy]&.resource&.class
          title = "Render #{resource_class&.name || ANONYMOUS}"
          desc = nil

          [CAT, title, desc]
        end
      end
    end
  end
end
