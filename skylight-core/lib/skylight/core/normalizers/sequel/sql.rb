require "skylight/core/normalizers/sql"

module Skylight::Core
  module Normalizers
    module Sequel
      # Normalizer for SQL requests
      class SQL < Skylight::Core::Normalizers::SQL
        register "sql.sequel"
      end
    end
  end
end
