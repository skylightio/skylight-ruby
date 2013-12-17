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

        binds = payload[:binds]

        if binds && !binds.empty?
          binds = binds.map { |col, val| val.inspect }
        end

        extracted_title, sql, binds, error = extract_binds(payload, binds)
        title = extracted_title if extracted_title

        if sql
          annotations = {
            sql:   sql,
            binds: binds,
          }
        else
          annotations = {
            skylight_error: error
          }
        end

        [ name, title, sql, annotations ]
      end

    private
      def extract_binds(payload, precalculated)
        title, sql, binds = SqlLexer::Lexer.bindify(payload[:sql], precalculated)
        [ title, sql, binds, nil ]
      rescue
        error = ["sql_parse", encode(payload[:sql]), encode(payload: payload, precalculated: precalculated)]
        [ nil, nil, nil, error ]
      end

      def encode(body)
        if body.is_a?(Hash)
          body.each{|k,v| body[k] = encode(v) }
        elsif body.is_a?(Array)
          body.each_with_index{|v,i| body[i] = encode(v) }
        elsif body.respond_to?(:encoding) && (body.encoding == Encoding::BINARY || !body.valid_encoding?)
          Base64.encode64(body)
        else
          body
        end
      end
    end
  end
end
