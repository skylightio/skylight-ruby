module Skylight
  module Normalizers
    module Elasticsearch
      class Request < Normalizer
        register "request.elasticsearch"

        CAT = "db.elasticsearch.request".freeze

        def normalize(trace, name, payload)
          path = payload[:path].split('/')
          title = [payload[:method], path[0]].compact.join(' ')
          desc = {}
          desc[:type] = path[1] if path[1]
          desc[:id] = '?' if path[2]
          [ CAT, title, desc.presence.try(:to_json) ]
        end
      end
    end
  end
end
