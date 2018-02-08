require 'skylight/core/normalizers/sql'

module Skylight::Core
  module Normalizers
    module DataMapper
      # Normalizer for SQL requests
      class SQL < Skylight::Core::Normalizers::SQL
        register "sql.data_mapper"
      end
    end
  end
end
