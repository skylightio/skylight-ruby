module Skylight
  module Core
    module Test
      module Mocking

        def mock!(config_opts={}, &callback)
          config_opts[:mock_submission] ||= callback || proc {}
          config = config_class.load(config_opts)

          mock_instrumenter_klass = Class.new(instrumenter_class) do
            def self.trace_class
              @trace_class ||= Class.new(super) do
                def self.native_new(start, _uuid, endpoint, meta)
                  inst = allocate
                  inst.instance_variable_set(:@start, start)
                  inst.instance_variable_set(:@endpoint, endpoint)
                  inst.instance_variable_set(:@starting_endpoint, endpoint)
                  inst.instance_variable_set(:@meta, meta)
                  inst
                end

                attr_reader :endpoint, :starting_endpoint, :meta

                def mock_spans
                  @mock_spans ||= []
                end

                def native_get_started_at
                  @start
                end

                def native_set_endpoint(endpoint)
                  @endpoint = endpoint
                end

                def native_start_span(time, cat)
                  span = {
                    start: time,
                    cat: cat
                  }
                  mock_spans << span
                  # Return integer like the native method does
                  mock_spans.index(span)
                end

                def native_span_set_title(sp, title)
                  mock_spans[sp][:title] = title

                end

                def native_span_set_description(sp, desc)
                  mock_spans[sp][:desc] = desc
                end

                def native_span_set_meta(sp, meta)
                  mock_spans[sp][:meta] = meta
                end

                def native_span_set_exception(sp, exception_object, exception)
                  mock_spans[sp][:exception_object] = exception_object
                  mock_spans[sp][:exception] = exception
                end

                def native_stop_span(span, time)
                  span = mock_spans[span]
                  span[:duration] = time - span[:start]
                  nil
                end
              end
            end

            def self.native_new(*)
              allocate
            end

            def native_start
              true
            end

            def native_submit_trace(trace)
              config[:mock_submission].call(trace)
            end

            def native_stop
            end

            def limited_description(description)
              description
            end
          end

          @instrumenter = mock_instrumenter_klass.new(config).start!
        end

      end
    end
  end
end
