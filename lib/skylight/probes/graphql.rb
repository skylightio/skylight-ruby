# frozen_string_literal: true

require "active_support/inflector"

module Skylight
  module Probes
    module GraphQL
      module Instrumentation
        def initialize(*, **)
          super

          return unless defined?(@tracers)

          # This is the legacy tracing used in graphql =< 2.0.17
          unless @tracers.include?(::GraphQL::Tracing::ActiveSupportNotificationsTracing)
            @tracers << ::GraphQL::Tracing::ActiveSupportNotificationsTracing
          end
        end
      end

      module InstrumentationV2
        def self.included(base)
          base.singleton_class.prepend ClassMethods
        end

        # GraphQL versions 2.0.18 - 2.0.21 (or higher?) were missing this notification
        module ExecuteMultiplexNotification
          def execute_multiplex(**metadata, &blk)
            if @notifications_engine
              @notifications_engine.instrument("execute_multiplex.graphql", metadata, &blk)
            else
              # safety fallback in case graphql's authors unexpectedly rename @notifications_engine
              super
            end
          end
        end

        # GraphQL versions >= 2.5 are missing this notification
        module ExecuteQueryNotification
          def execute_query(**metadata, &blk)
            if @notifications_engine
              @notifications_engine.instrument("execute_query.graphql", metadata, &blk)
            elsif @notifications
              @notifications.instrument("execute_query.graphql", metadata, &blk)
            else
              # safety fallback in case graphql's authors unexpectedly rename @notifications_engine or @notifications
              super
            end
          end
        end

        # GraphQL versions >= 2.5 are missing this notification
        module ExecuteQueryLazyNotification
          def execute_query_lazy(**metadata, &blk)
            if @notifications_engine
              @notifications_engine.instrument("execute_query_lazy.graphql", metadata, &blk)
            elsif @notifications
              @notifications.instrument("execute_query_lazy.graphql", metadata, &blk)
            else
              # safety fallback in case graphql's authors unexpectedly rename @notifications_engine or @notifications
              super
            end
          end
        end

        # GraphQL versions >= 2.5 are missing this notification
        module AnalyzeQueryNotification
          def analyze_query(**metadata, &blk)
            if @notifications_engine
              @notifications_engine.instrument("analyze_query.graphql", metadata, &blk)
            elsif @notifications
              @notifications.instrument("analyze_query.graphql", metadata, &blk)
            else
              # safety fallback in case graphql's authors unexpectedly rename @notifications_engine or @notifications
              super
            end
          end
        end

        module ClassMethods
          def new_trace(*, **)
            unless @__sk_instrumentation_installed
              trace_with(::GraphQL::Tracing::ActiveSupportNotificationsTrace)

              unless ::GraphQL::Tracing::ActiveSupportNotificationsTrace.instance_methods.include?(:execute_multiplex)
                trace_with(ExecuteMultiplexNotification)
              end

              unless ::GraphQL::Tracing::ActiveSupportNotificationsTrace.instance_methods.include?(:execute_query)
                trace_with(ExecuteQueryNotification)
              end

              unless ::GraphQL::Tracing::ActiveSupportNotificationsTrace.instance_methods.include?(:execute_query_lazy)
                trace_with(ExecuteQueryLazyNotification)
              end

              unless ::GraphQL::Tracing::ActiveSupportNotificationsTrace.instance_methods.include?(:analyze_query)
                trace_with(AnalyzeQueryNotification)
              end

              @__sk_instrumentation_installed = true
            end

            super
          end
        end
      end

      class Probe
        def install
          new_tracing = false
          begin
            require "graphql/tracing/active_support_notifications_trace"
            new_tracing = true
          rescue LoadError # rubocop:disable Lint/SuppressedException
          end

          if new_tracing
            # GraphQL >= 2.0.18
            ::GraphQL::Schema.include(InstrumentationV2)
          else
            tracing_klass_name = "::GraphQL::Tracing::ActiveSupportNotificationsTracing"
            klasses_to_probe = %w[::GraphQL::Execution::Multiplex ::GraphQL::Query]

            return unless ([tracing_klass_name] + klasses_to_probe).all?(&method(:safe_constantize))

            klasses_to_probe.each { |klass_name| safe_constantize(klass_name).prepend(Instrumentation) }
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
