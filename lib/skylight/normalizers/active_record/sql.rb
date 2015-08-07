require "sql_lexer"
require "json"

module Skylight
  module Normalizers
    module ActiveRecord
      class SQL < Normalizer
        register "sql.active_record"
        register "sql.sequel"
        register "sql.data_mapper"

        CAT = "db.sql.query".freeze

        def normalize(trace, name, payload)
          case payload[:name]
          when "SCHEMA", "CACHE"
            return :skip
          else
            name  = CAT
            title = payload[:name] || "SQL"
          end

          binds = payload[:binds]

          if binds && !binds.empty?
            binds = binds.map { |col, val| val.inspect }
          end

          begin
            extracted_title, sql = extract_binds(payload, binds)
            [ name, extracted_title || title, sql ]
          rescue
            [ name, title, nil ]
          end
        end

        private

        if ENV["SKYLIGHT_SQL_MODE"] == "rust"
          def extract_binds(payload, _)
            Skylight.lex_sql(payload[:sql])
          end
        else
          def extract_binds(payload, precalculated)
            name, title, _ = SqlLexer::Lexer.bindify(payload[:sql], precalculated, true)
            [ name, title ]
          end
        end
      end
    end
  end
end
