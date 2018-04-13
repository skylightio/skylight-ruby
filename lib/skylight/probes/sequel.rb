# Supports 3.12.0+
module Skylight
  module Probes
    module Sequel
      class Probe
        def install
          if Gem::Version.new(::Sequel.version) < Gem::Version.new('4.0')
            Skylight::DEPRECATOR.deprecation_warning("Support for Sequel versions before 4.0")
          end

          require 'sequel/database/logging'

          method_name = ::Sequel::Database.method_defined?(:log_connection_yield) ? 'log_connection_yield' : 'log_yield'

          ::Sequel::Database.class_eval <<-end_eval
            alias #{method_name}_without_sk #{method_name}

            def #{method_name}(sql, *args, &block)
              #{method_name}_without_sk(sql, *args) do
                ::ActiveSupport::Notifications.instrument(
                  "sql.sequel",
                  sql: sql,
                  name: "SQL",
                  binds: args
                ) do
                  block.call
                end
              end
            end
          end_eval
        end
      end
    end

    register("Sequel", "sequel", Sequel::Probe.new)
  end
end
