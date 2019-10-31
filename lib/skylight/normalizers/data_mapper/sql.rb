require "skylight/normalizers/sql"

module Skylight
  module Normalizers
    module DataMapper
      # Normalizer for SQL requests
      class SQL < Skylight::Normalizers::SQL
        register "sql.data_mapper"
      end
    end
  end
end
