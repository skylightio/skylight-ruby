# Supports 3.12.0+
module Skylight::Core
  module Probes
    module Sequel
      class Probe
        def install
          require "sequel/database/logging"

          method_name = ::Sequel::Database.method_defined?(:log_connection_yield) ? "log_connection_yield" : "log_yield"

          ::Sequel::Database.class_eval <<-RUBY, __FILE__, __LINE__ + 1
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
          RUBY
        end
      end
    end

    register(:sequel, "Sequel", "sequel", Sequel::Probe.new)
  end
end
