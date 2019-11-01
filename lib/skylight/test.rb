module Skylight
  module Test
    module Mocking
      def mock!(config_opts = {}, &callback)
        config_opts[:mock_submission] ||= callback || proc {}
        config = config_class.load(config_opts)

        unless respond_to?(:__original_instrumenter_class)
          class_eval do
            class << self
              alias_method :__original_instrumenter_class, :instrumenter_class

              def instrumenter_class
                @instrumenter_class ||= Class.new(__original_instrumenter_class) do
                  def self.name
                    "Mocked Instrumenter"
                  end

                  def self.native_new(*)
                    allocate
                  end

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

                      def native_span_set_title(span, title)
                        mock_spans[span][:title] = title
                      end

                      def native_span_set_description(span, desc)
                        mock_spans[span][:desc] = desc
                      end

                      def native_span_set_meta(span, meta)
                        mock_spans[span][:meta] = meta
                      end

                      def native_span_started(span); end

                      def native_span_set_exception(span, exception_object, exception)
                        mock_spans[span][:exception_object] = exception_object
                        mock_spans[span][:exception] = exception
                      end

                      def native_stop_span(span, time)
                        span = mock_spans[span]
                        span[:duration] = time - span[:start]
                        nil
                      end
                    end
                  end

                  def native_start
                    true
                  end

                  def native_submit_trace(trace)
                    config[:mock_submission].call(trace)
                  end

                  def native_stop; end

                  def limited_description(description)
                    description
                  end
                end
              end
            end
          end
        end

        start!(config)
      end
    end
  end
end
