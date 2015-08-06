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

          extracted_title, sql, binds = extract_binds(payload, binds)
          title = extracted_title if extracted_title

          [ name, title, sql ]
        end

      private
        def extract_binds(payload, precalculated)
          SqlLexer::Lexer.bindify(payload[:sql], precalculated, true)
        rescue => e
          # TODO: log
          [ nil, nil, nil ]
        end
      end
    end
  end
end
