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
      rescue => e
        group = "sql_parse"
        description = e.inspect
        details = encode(backtrace: e.backtrace,
                          original_exception: {
                            class_name: e.class.name,
                            message: e.message
                          },
                          payload: payload,
                          precalculated: precalculated)

        error = [group, description, details]
        [ nil, nil, nil, error ]
      end

      # While operating in place would save memory, some of these passed in items are re-used elsewhere
      # and, as such, should not be modified.
      def encode(body)
        if body.is_a?(Hash)
          hash = {}
          body.each{|k,v| hash[k] = encode(v) }
          hash
        elsif body.is_a?(Array)
          body.map{|v| encode(v) }
        elsif body.respond_to?(:encoding) && (body.encoding == Encoding::BINARY || !body.valid_encoding?)
          Base64.encode64(body)
        else
          body
        end
      end
    end
  end
end
