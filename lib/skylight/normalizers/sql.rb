require "sql_lexer"
require "json"

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
          title = payload[:name] || "SQL"
        end

        if payload[:binds].empty?
          payload[:sql], binds, error = extract_binds(payload)
        else
          binds = payload[:binds].map { |col, val| val.inspect }
        end


        if payload[:sql]
          annotations = {
            sql:   payload[:sql],
            binds: binds,
          }
        else
          annotations = {
            skylight_error: error
          }
        end

        [ name, title, payload[:sql], annotations ]
      end

    private
      def extract_binds(payload)
        sql, binds = SqlLexer::Lexer.bindify(payload[:sql])
        [ sql, binds, nil ]
      rescue
        [ nil, nil, ["sql_parse", payload[:sql]] ]
      end
    end
  end
end
