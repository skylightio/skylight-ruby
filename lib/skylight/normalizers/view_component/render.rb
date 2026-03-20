module Skylight
  module Normalizers
    module ViewComponent
      class Render < Normalizer
        register "render.view_component"

        CAT = "view.render.component".freeze

        def normalize(_trace, _name, payload)
          title = payload[:name]
          meta = {}
          meta[:source_file] = payload[:identifier] if payload[:identifier]
          [CAT, title, nil, meta]
        end
      end
    end
  end
end
