# frozen_string_literal: true

module Skylight::Core
  module Normalizers
    module Graphiti
      class Resolve < Normalizer
        register "resolve.graphiti"

        CAT = "app.resolve.graphiti"

        ANONYMOUS_RESOURCE = "<Anonymous Resource>"
        ANONYMOUS_ADAPTER = "<Anonymous Adapter>"

        def normalize(_trace, _name, payload)
          resource = payload[:resource]

          if (sideload = payload[:sideload])
            type = sideload.type.to_s.split("_").map(&:capitalize).join(" ")
            desc = "Custom Scope" if sideload.class.scope_proc
          else
            type = "Primary"
          end

          title = "Resolve #{type} #{resource.class.name || ANONYMOUS_RESOURCE}"

          [CAT, title, desc]
        end
      end
    end
  end
end
