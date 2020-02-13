# frozen_string_literal: true

module Skylight
  module Probes
    module GraphQL
      class Probe
        if Gem::Version.new(::GraphQL::VERSION) >= Gem::Version.new("1.10")
          def install
            ::GraphQL::Schema.instance_eval do
              class << self
                alias_method :multiplex_without_sk, :multiplex # rubocop:disable Style/Alias
              end

              # Schema#execute also delegates to multiplex, so this is the only method
              # we need to override.
              def multiplex(*args, **kwargs)
                sk_add_tracer
                multiplex_without_sk(*args, **kwargs)
              end

              def sk_add_tracer
                Skylight::Config::MUTEX.synchronize do
                  graphql_tracer = ::GraphQL::Tracing::ActiveSupportNotificationsTracing
                  unless tracers.include?(graphql_tracer)
                    $stdout.puts "[SKYLIGHT] Adding tracer 'GraphQL::Tracing::ActiveSupportNotificationsTracing' to schema" # rubocop:disable Metrics/LineLength
                    tracer(graphql_tracer)
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
        else
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
                    $stdout.puts "[SKYLIGHT] Adding tracer 'GraphQL::Tracing::ActiveSupportNotificationsTracing' to schema" # rubocop:disable Metrics/LineLength
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
    end

    register(:graphql, "GraphQL", "graphql", GraphQL::Probe.new)
  end
end
