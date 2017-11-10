unless ENV['SKYLIGHT_DISABLE_AGENT']
  module SpecHelper

    def mock_instrumenter!(&callback)
      config = Skylight::Core::Config.new(mock_submission: callback || proc {})
      Skylight.instance_variable_set(:@instrumenter, Skylight::Core::MockInstrumenter.new(config).start!)
    end

  end

  module Skylight

    module Core
      class MockInstrumenter < Instrumenter

        def self.trace_class
          MockTrace
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

      class MockTrace < Trace

        class << self

          def native_new(start, uuid, endpoint)
            inst = allocate
            inst.instance_variable_set(:@start, start)
            inst
          end

        end

        def mock_spans
          @mock_spans ||= []
        end

        def native_get_started_at
          @start
        end

        def native_set_endpoint(*args)
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

        def native_stop_span(span, time)
          span = mock_spans[span]
          span[:duration] = time - span[:start]
          nil
        end

      end
    end

  end

end
