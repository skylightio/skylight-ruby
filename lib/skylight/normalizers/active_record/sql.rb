require "skylight/normalizers/sql"

module Skylight
  module Normalizers
    module ActiveRecord
      # Normalizer for SQL requests
      class SQL < Skylight::Normalizers::SQL
        register "sql.active_record"
      end
    end
  end
end
