require "json"

module Skylight::Core
  module Normalizers
    # Normalizer for SQL requests
    class SQL < Normalizer
      CAT = "db.sql.query".freeze

      # @param trace [Skylight::Messages::Trace::Builder] ignored, only present to match API
      # @param name [String] ignored, only present to match API
      # @param payload [Hash]
      # @option payload [String] [:name] The SQL operation
      # @option payload [Hash] [:binds] The bound parameters
      # @return [Array]
      def normalize(trace, name, payload)
        case payload[:name]
        when "SCHEMA".freeze, "CACHE".freeze
          return :skip
        else
          name  = CAT
          title = payload[:name] || "SQL".freeze
        end

        binds = payload[:binds]

        if binds && !binds.empty?
          binds = binds.map { |_col, val| val.inspect }
        end

        begin
          extracted_title, sql = extract_binds(trace.instrumenter, payload, binds)
          [name, extracted_title || title, sql]
        rescue => e
          if defined?(Skylight::SqlLexError) && e.is_a?(Skylight::SqlLexError)
            if config[:log_sql_parse_errors]
              config.logger.error "[#{e.formatted_code}] Failed to extract binds from SQL query. " \
                                  "It's likely that this query uses more advanced syntax than we currently support. " \
                                  "sql=#{payload[:sql].inspect}"
            end
          else
            config.logger.error "Failed to extract binds in SQL; sql=#{payload[:sql].inspect}; exception=#{e.inspect}"
          end

          [name, title, nil]
        end
      end

      private

      def extract_binds(instrumenter, payload, _precalculated)
        instrumenter.process_sql(payload[:sql])
      end
    end
  end
end
