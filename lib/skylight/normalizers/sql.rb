# frozen_string_literal: true

require "json"

module Skylight
  module Normalizers
    # Normalizer for SQL requests
    class SQL < Normalizer
      CAT = "db.sql.query"

      # @param trace [Skylight::Messages::Trace::Builder] ignored, only present to match API
      # @param name [String] ignored, only present to match API
      # @param payload [Hash]
      # @option payload [String] [:name] The SQL operation
      # @option payload [Hash] [:binds] The bound parameters
      # @return [Array]
      def normalize(_trace, _name, payload)
        return :skip if payload[:name] == "SCHEMA" || payload[:name] == "CACHE"

        title = payload[:name] || "SQL"

        # We can only handle UTF-8 encoded strings.
        # (Construction method here avoids extra allocations)
        sql = String.new.concat("<sk-sql>", payload[:sql], "</sk-sql>").force_encoding(Encoding::UTF_8)

        unless sql.valid_encoding?
          if config[:log_sql_parse_errors]
            config.logger.error "[#{Skylight::SqlLexError.formatted_code}] Unable to extract binds from non-UTF-8 " \
                                  "query. " \
                                  "encoding=#{payload[:sql].encoding.name} " \
                                  "sql=#{payload[:sql].inspect} "
          end

          sql = nil
        end

        [CAT, title, sql]
      end
    end
  end
end
