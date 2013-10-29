require "sql_lexer"

module Skylight
  module Normalizers
    class SQL < Normalizer
      register "sql.active_record"

      def normalize(trace, name, payload)
        case payload[:name]
        when "SCHEMA", "CACHE"
          return :skip
        else
          name  = "db.sql.query"
          title = payload[:name]
        end

        if payload[:binds].empty?
          payload[:sql], binds, error = extract_binds(payload)
        else
          binds = payload[:binds].map(&:last)
        end

        annotations = {
          sql:   payload[:sql],
          binds: binds,
        }

        annotations[:skylight_error] = error if error

        [ name, title, payload[:sql], annotations ]
      end

    private
      def extract_binds(payload)
        sql, binds = SqlLexer::Lexer.bindify(payload[:sql])
        [ sql, binds, nil ]
      rescue
        [ nil, nil, [:sql_parse, payload[:sql]] ]
      end
    end
  end
end
