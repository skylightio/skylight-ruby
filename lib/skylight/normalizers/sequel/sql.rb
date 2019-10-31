require "skylight/normalizers/sql"

module Skylight
  module Normalizers
    module Sequel
      # Normalizer for SQL requests
      class SQL < Normalizers::SQL
        register "sql.sequel"
      end
    end
  end
end
