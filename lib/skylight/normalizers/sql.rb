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
          extracted_title, payload[:sql], binds, error = extract_binds(payload)
        else
          extracted_title, _, _, error = extract_binds(payload)
          binds = payload[:binds].map { |col, val| val.inspect }
        end

        title = extracted_title if extracted_title


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
        title, sql, binds = SqlLexer::Lexer.bindify(payload[:sql])
        [ title, sql, binds, nil ]
      rescue
        [ nil, nil, nil, ["sql_parse", payload[:sql]] ]
      end
    end
  end
end
