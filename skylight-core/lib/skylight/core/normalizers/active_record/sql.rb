require 'skylight/core/normalizers/sql'

module Skylight::Core
  module Normalizers
    module ActiveRecord
      # Normalizer for SQL requests
      class SQL < Skylight::Core::Normalizers::SQL
        register "sql.active_record"

        def normalize(trace, name, payload)
          ret = super
          return :skip if ret == :skip

          name, title, description, meta = ret

          meta ||= {}

          # FIXME: This may not be correct if the class has a different connection
          begin
            config = ::ActiveRecord::Base.connection_config
            meta[:adapter] = config[:adapter]
            meta[:database] = config[:database]
          rescue => e
            warn "Unable to get ActiveRecord config; e=#{e}"
          end

          [name, title, description, meta]
        end

      end
    end
  end
end
