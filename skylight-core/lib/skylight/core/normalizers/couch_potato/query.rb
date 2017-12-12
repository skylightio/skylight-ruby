require "json"

module Skylight::Core
  module Normalizers
    module CouchPotato
      class Query < Normalizer
        register "couch_potato.load"
        register "couch_potato.view"

        CAT = "db.couch_db.query".freeze

        def normalize(trace, name, payload, instrumenter)
          description = payload[:name] if payload
          _name = name.sub('couch_potato.', '')
          [CAT, _name, description]
        end
      end
    end
  end
end