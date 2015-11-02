module Skylight
  module Probes
    module Grape
      class Probe
        def install
          version = Gem::Version.new(::Grape::VERSION)

          if version > Gem::Version.new("0.12.1")
            # AS::N is built in to newer versions
            return
          end

          if version < Gem::Version.new("0.10.0")
            # Using $stderr here isn't great, but we don't have a logger accessible
            $stderr.puts "[SKYLIGHT] [#{Skylight::VERSION}] The Grape probe only works with version 0.10.0+ " \
                          "and will be disabled."

            return
          end

          # Grape relies on this but does doesn't correctly require it.
          # However, when using ActiveSupport 4 it is implicitly loaded,
          #   in AS 3, it will fail.
          # https://github.com/ruby-grape/grape/issues/1087
          require 'active_support/core_ext/hash/except'

          ::Grape::Endpoint.class_eval do
            alias initialize_without_sk initialize
            def initialize(*args, &block)
              initialize_without_sk(*args, &block)

              # This solution of wrapping the block is effective, but potentially fragile.
              # A cleaner solution would be to call the original initialize with the already
              # modified block. However, Grape does some odd stuff with the block binding
              # that makes this difficult to reason about.
              if original_block = @block
                @block = lambda do |endpoint_instance|
                  ActiveSupport::Notifications.instrument('endpoint_render.grape', endpoint: endpoint_instance) do
                    original_block.call(endpoint_instance)
                  end
                end
              end
            end

            alias run_without_sk run
            def run(*args)
              ActiveSupport::Notifications.instrument('endpoint_run.grape', endpoint: self) do
                run_without_sk(*args)
              end
            end

            alias run_filters_without_sk run_filters
            def run_filters(filters)
              # Unfortunately, the type isn't provided to the method so we have
              # to try to guess it by looking at the contents. This is only reliable
              # if the filters aren't empty.
              if filters && !filters.empty?
                type = case filters
                  when befores            then :before
                  when before_validations then :before_validation
                  when after_validations  then :after_validation
                  when afters             then :after
                  else                         :other
                  end
              else
                type = :unknown
              end

              payload = {
                endpoint: self,
                filters: filters,
                type: type
              }

              ActiveSupport::Notifications.instrument('endpoint_run_filters.grape', payload) do
                run_filters_without_sk(filters)
              end
            end
          end
        end
      end
    end

    register("Grape::Endpoint", "grape/endpoint", Grape::Probe.new)
  end
end