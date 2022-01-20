require "skylight/normalizers/sql"

module Skylight
  module Normalizers
    module ActiveRecord
      # Normalizer for SQL requests
      class SQL < Skylight::Normalizers::SQL
        register "sql.active_record"
      end

      class FutureResult < Normalizer
        register "future_result.active_record"

        def normalize(_trace, _name, payload)
          ["db.future_result", "Async #{payload[:args][1] || "Query"}"]
        end
      end
    end
  end
end
