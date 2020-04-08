# frozen_string_literal: true

require "active_support/inflector"

module Skylight
  module Probes
    module GraphQL
      module Instrumentation
        def initialize(*, **)
          super

          return unless defined?(@tracers)

          unless @tracers.include?(::GraphQL::Tracing::ActiveSupportNotificationsTracing)
            @tracers << ::GraphQL::Tracing::ActiveSupportNotificationsTracing
          end
        end
      end

      class Probe
        def install
          tracing_klass_name = "::GraphQL::Tracing::ActiveSupportNotificationsTracing"
          klasses_to_probe = %w[
            ::GraphQL::Execution::Multiplex
            ::GraphQL::Query
          ]

          return unless ([tracing_klass_name] + klasses_to_probe).all?(&method(:safe_constantize))

          klasses_to_probe.each do |klass_name|
            safe_constantize(klass_name).prepend(Instrumentation)
          end
        end

        def safe_constantize(klass_name)
          ActiveSupport::Inflector.safe_constantize(klass_name)
        end
      end
    end

    register(:graphql, "GraphQL", "graphql", GraphQL::Probe.new)
  end
end
