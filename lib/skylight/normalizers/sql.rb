require "sql_lexer"
require "json"

module Skylight
  module Normalizers
    class SQL < Normalizer
      register "sql.active_record"

      CAT = "db.sql.query".freeze

      def normalize(trace, name, payload)
        case payload[:name]
        when "SCHEMA", "CACHE"
          return :skip
        else
          name  = CAT
          title = payload[:name] || "SQL"
        end

        # We don't want to modify the original payload since other non-Skylight subscribers may use it
        payload = payload.dup

        unless payload[:binds].empty?
          payload[:binds] = payload[:binds].map { |col, val| val.inspect }
        end

        extracted_title, payload[:sql], binds, error = extract_binds(payload, payload[:binds])
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
      def extract_binds(payload, precalculated)
        title, sql, binds = SqlLexer::Lexer.bindify(payload[:sql], precalculated)
        [ title, sql, binds, nil ]
      rescue
        [ nil, nil, nil, ["sql_parse", payload[:sql]] ]
      end
    end
  end
end
