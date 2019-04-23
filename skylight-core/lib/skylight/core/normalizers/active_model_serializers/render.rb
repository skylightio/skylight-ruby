module Skylight::Core
  module Normalizers
    module ActiveModelSerializers
      class Render < Normalizer
        register "render.active_model_serializers"

        CAT = "view.render.active_model_serializers".freeze
        ANONYMOUS = "<Anonymous Serializer>".freeze

        def normalize(_trace, _name, payload)
          serializer_class = payload[:serializer]

          title = serializer_class.name || ANONYMOUS
          title = title.sub(/^ActiveModel::(Serializer::)?/, "")

          if (adapter_instance = payload[:adapter])
            adapter_name = adapter_instance.class.name.to_s.
                           sub(/^ActiveModel::Serializer::Adapter::/, "").
                           sub(/^ActiveModelSerializers::Adapter::/, "")
            desc = "Adapter: #{adapter_name}"
          end

          [CAT, title, desc]
        end
      end
    end
  end
end
