require "json"

module Skylight
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

        # Encode since we could have SQL with binary data
        sql = payload[:sql].encode('UTF-8', invalid: :replace, undef: :replace, replace: '�')

        [name, title, "<sk-sql>#{sql}</sk-sql>"]
      end
    end
  end
end
