module Skylight::Core
  module Probes
    module GraphQL
      class Probe
        def install
          ::GraphQL::Schema.class_eval do
            alias_method :execute_without_sk, :execute
            alias_method :multiplex_without_sk, :multiplex

            def multiplex(*args, &block)
              sk_add_tracer(:multiplex)
              multiplex_without_sk(*args, &block)
            end

            def execute(*args, &block)
              sk_add_tracer(:execute)
              execute_without_sk(*args, &block)
            end

            def sk_add_tracer(method_name)
              Skylight::Core::Config::MUTEX.synchronize do
                graphql_tracer = ::GraphQL::Tracing::ActiveSupportNotificationsTracing
                if !tracers.include?(graphql_tracer)
                  $stderr.puts "Adding ::GraphQL::Tracing::ActiveSupportNotificationsTracing to schema"
                  tracers << graphql_tracer
                end

                instance_eval <<-RUBY, __FILE__, __LINE__ + 1
                  class << self
                    # Remove the probe and reset multiplex/execute to original version
                    alias_method :#{method_name}, :#{method_name}_without_sk
                  end
                RUBY
              end
            end
          end
        end
      end
    end

    register(:graphql, "GraphQL", "graphql", GraphQL::Probe.new)
  end
end
