require "json"

module Skylight::Core
  module Normalizers
    module ActiveRecord
      # Normalizer for SQL requests
      class SQL < Normalizer
        register "sql.active_record"
        register "sql.sequel"
        register "sql.data_mapper"

        CAT = "db.sql.query".freeze

        # @param trace [Skylight::Messages::Trace::Builder] ignored, only present to match API
        # @param name [String] ignored, only present to match API
        # @param payload [Hash]
        # @option payload [String] [:name] The SQL operation
        # @option payload [Hash] [:binds] The bound parameters
        # @return [Array]
        def normalize(trace, name, payload, instrumenter)
          case payload[:name]
          when "SCHEMA".freeze, "CACHE".freeze
            return :skip
          else
            name  = CAT
            title = payload[:name] || "SQL".freeze
          end

          binds = payload[:binds]

          if binds && !binds.empty?
            binds = binds.map { |col, val| val.inspect }
          end

          begin
            extracted_title, sql = extract_binds(payload, binds)
            [ name, extracted_title || title, sql ]
          rescue => e
            # FIXME: Rust errors get written to STDERR and don't come through here
            if config[:log_sql_parse_errors]
              config.logger.warn "failed to extract binds in SQL; sql=#{payload[:sql].inspect}; exception=#{e.inspect}"
            end
            [ name, title, nil ]
          end
        end

        private

        def extract_binds(payload, precalculated)
          Skylight.lex_sql(payload[:sql])
        end
      end
    end
  end
end
