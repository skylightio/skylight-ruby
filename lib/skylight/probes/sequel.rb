# Supports 3.12.0+
module Skylight
  module Probes
    module Sequel
      class Probe
        def install
          require "sequel/database/logging"

          method_name = ::Sequel::Database.method_defined?(:log_connection_yield) ? "log_connection_yield" : "log_yield"

          mod =
            Module.new do
              define_method method_name do |sql, *args, &block|
                super(sql, *args) do
                  ::ActiveSupport::Notifications.instrument("sql.sequel", sql: sql, name: "SQL", binds: args) do
                    block.call
                  end
                end
              end
            end

          ::Sequel::Database.prepend(mod)
        end
      end
    end

    register(:sequel, "Sequel", "sequel", Sequel::Probe.new)
  end
end
