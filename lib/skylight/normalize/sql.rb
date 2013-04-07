module Skylight
  module Normalize
    class SQL < Normalizer
      register "sql.active_record"

      def normalize
        if @payload[:name] == "SCHEMA"
          return :skip
        elsif @payload[:name] == "CACHE"
          name = "db.sql.cache"
          title = "Cached Load"
        else
          name = "db.sql.query"
          title = @payload[:name]
        end

        annotations = {
          sql: @payload[:sql],
          binds: @payload[:binds].map(&:last)
        }

        [ name, title, nil, annotations ]
      end
    end
  end
end
