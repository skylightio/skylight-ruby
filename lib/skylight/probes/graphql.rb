# frozen_string_literal: true

module Skylight
  module Probes
    module GraphQL
      class Probe
        def install
          ::GraphQL::Schema.class_eval do
            alias_method :multiplex_without_sk, :multiplex

            # Schema#execute also delegates to multiplex, so this is the only method
            # we need to override.
            def multiplex(*args, &block)
              sk_add_tracer
              multiplex_without_sk(*args, &block)
            end

            def sk_add_tracer
              Skylight::Config::MUTEX.synchronize do
                graphql_tracer = ::GraphQL::Tracing::ActiveSupportNotificationsTracing
                unless tracers.include?(graphql_tracer)
                  $stdout.puts "[SKYLIGHT] Adding tracer " \
                               "'GraphQL::Tracing::ActiveSupportNotificationsTracing' to schema"
                  tracers << graphql_tracer
                end

                class << self
                  # Remove the probe and reset multiplex/execute to original version
                  # after the tracer has been added
                  alias_method :multiplex, :multiplex_without_sk
                end
              end
            end
          end
        end
      end
    end

    register(:graphql, "GraphQL", "graphql", GraphQL::Probe.new)
  end
end
