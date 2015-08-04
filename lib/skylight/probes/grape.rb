module Skylight
  module Probes
    module Grape
      class Probe
        def install
          version = ::Grape::VERSION.split('.')
          if version[0] == '0' && version[1].to_i < 10
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
                opts = {
                  category: "app.grape.endpoint",
                  title: method_name.gsub(/\s+/, ' ')
                }

                @block = lambda do |endpoint_instance|
                  Skylight.instrument(opts) do
                    original_block.call(endpoint_instance)
                  end
                end
              end
            end

            alias run_without_sk run
            def run(*args)
              # We run the original method first since it gives us access to more information
              # about the current state, including populating `route`.
              run_without_sk(*args)
            ensure
              if instrumenter = Skylight::Instrumenter.instance
                if trace = instrumenter.current_trace
                  # FIXME: How do we handle endpoints with multiple methods?
                  #   Currently we'll see things like "PUT POST DELETE PATCH HEAD"

                  # OPTION A: GET /prefix/name [v1]
                  # # FIXME: Ideally we wouldn't have to do this, but I don't know
                  # #   of a better way
                  # info = route.instance_variable_get :@options

                  # # FIXME: Consider whether we should include the module name
                  # name = "#{info[:method]} #{info[:path]}"
                  # name << " [#{info[:version]}]" if info[:version]


                  # OPTION B: Module::Class GET /name
                  http_method = options[:method].first
                  http_method << "..." if options[:method].length > 1

                  path = options[:path].join("/")
                  namespace = ::Grape::Namespace.joined_space(namespace_stackable(:namespace))

                  if namespace && !namespace.empty?
                    path = "/#{path}" if path[0] != '/'
                    path = "#{namespace}#{path}"
                  end

                  name = "#{options[:for]} [#{http_method}] #{path}"

                  trace.endpoint = name
                end
              end
            end

            alias run_filters_without_sk run_filters
            def run_filters(filters)
              if !filters || filters.empty?
                # If there's no filters nothing should happen, but let Grape decide
                return run_filters_without_sk(filters)
              end

              # Unfortunately, this method only gets passed an array of filters.
              # This means we have to compare to known lists to attempt to detect
              # the type.
              type = case filters
                when befores            then "Before"
                when before_validations then "Before Validation"
                when after_validations  then "After Validation"
                when afters             then "After"
                else                         "Other"
                end

              opts = {
                category: "app.grape.filters",
                title: "#{type} Filters"
              }

              Skylight.instrument(opts) do
                run_filters_without_sk(filters)
              end
            end
          end
        end
      end
    end

    register("Grape", "grape", Grape::Probe.new)
  end
end