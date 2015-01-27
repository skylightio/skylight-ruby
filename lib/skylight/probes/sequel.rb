# Supports 3.12.0+
module Skylight
  module Probes
    module Sequel
      class Probe
        def install
          require 'sequel/database/logging'
          ::Sequel::Database.class_eval do
            alias log_yield_without_sk log_yield

            def log_yield(sql, args=nil, &block)
              log_yield_without_sk(sql, *args) do
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
          end
        end
      end
    end

    register("Sequel", "sequel", Sequel::Probe.new)
  end
end
