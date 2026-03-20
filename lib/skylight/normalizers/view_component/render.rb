module Skylight
  module Normalizers
    module ViewComponent
      class Render < Normalizer
        register "render.view_component"

        CAT = "view.render.component".freeze

        def normalize(_trace, _name, payload)
          [CAT, payload[:name], nil]
        end

        private

        def process_meta_options(payload)
          super.merge(source_location_hint: [:instance_method, payload[:name], "call"])
        end
      end
    end
  end
end
