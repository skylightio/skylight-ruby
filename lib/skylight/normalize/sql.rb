module Skylight
  module Normalize
    class SQL < Normalizer
      register "sql.active_record"

      def normalize
        case @payload[:name]
        when "SCHEMA", "CACHE"
          return :skip
        else
          name = "db.sql.query"
          title = @payload[:name]
        end

        binds = @payload[:binds]

        annotations = {
          sql: @payload[:sql],
          binds: binds ? binds.map(&:last) : []
        }

        [ name, title, nil, annotations ]
      end
    end
  end
end
