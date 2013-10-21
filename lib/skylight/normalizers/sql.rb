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
          payload[:sql], binds = SqlLexer::Lexer.bindify(payload[:sql])
        else
          binds = payload[:binds].map(&:last)
        end

        annotations = {
          sql:   payload[:sql],
          binds: binds,
        }

        [ name, title, payload[:sql], annotations ]
      end
    end
  end
end
