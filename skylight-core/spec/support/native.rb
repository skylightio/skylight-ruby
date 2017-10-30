unless ENV['SKYLIGHT_DISABLE_AGENT']

  module Skylight

    class << self
      alias native_without_mock? native?
      def native?
        if inst = Skylight::Core::Instrumenter.instance && inst.mocked?
          true
        else
          native_without_mock?
        end
      end
    end

    module Core
      class Instrumenter

        unless Skylight.native_without_mock?
          %w(native_submit_trace native_stop).each do |meth|
            define_method(meth) { raise "not native" }
          end
        end

        alias native_submit_trace_without_mock native_submit_trace
        alias native_stop_without_mock native_stop
        alias limited_description_without_mock limited_description

        def self.mock!(&callback)
          raise "already mocked" if @instance
          @instance = self.allocate.tap do |inst|
            inst.instance_eval do
              initialize Config.new(mock_submission: callback || proc {})
              @subscriber.register!
            end
          end
        end

        def mocked?
          config.key?(:mock_submission)
        end

        def native_submit_trace(trace)
          if mocked?
            config[:mock_submission].call(trace)
          else
            native_submit_trace_without_mock(trace)
          end
        end

        def native_stop
          native_stop_without_mock unless mocked?
        end

        def limited_description(description)
          if mocked?
            description
          else
            limited_description_without_mock(description)
          end
        end

      end

      class Trace

        class << self
          unless Skylight.native_without_mock?
            %w(native_new).each do |meth|
              define_method(meth) { raise "not native" }
            end
          end

          alias native_new_without_mock native_new

          def native_new(start, uuid, endpoint)
            if Skylight::Core::Instrumenter.instance.mocked?
              inst = allocate
              inst.instance_variable_set(:@start, start)
              inst
            else
              native_new_without_mock(start, uuid, endpoint)
            end
          end

        end

        unless Skylight.native_without_mock?
          %w(native_get_started_at native_set_endpoint native_start_span native_span_set_title
              native_span_set_description native_stop_span).each do |meth|
            define_method(meth) { raise "not native" }
          end
        end

        alias native_set_endpoint_without_mock native_set_endpoint
        alias native_get_started_at_without_mock native_get_started_at
        alias native_start_span_without_mock native_start_span
        alias native_span_set_title_without_mock native_span_set_title
        alias native_span_set_description_without_mock native_span_set_description
        alias native_stop_span_without_mock native_stop_span

        def mock_spans
          @mock_spans ||= []
        end

        def mocked?
          @instrumenter.mocked?
        end

        def native_get_started_at
          return native_get_started_at_without_mock unless mocked?
          @start
        end

        def native_set_endpoint(*args)
          return if mocked?
          native_set_endpoint_without_mock(*args)
        end

        def native_start_span(time, cat)
          return native_start_span_without_mock(time, cat) unless mocked?

          span = {
            start: time,
            cat: cat
          }
          mock_spans << span
          # Return integer like the native method does
          mock_spans.index(span)
        end

        def native_span_set_title(sp, title)
          return native_span_set_title_without_mock(sp, title) unless mocked?

          mock_spans[sp][:title] = title
        end

        def native_span_set_description(sp, desc)
          return native_span_set_description_without_mock(sp, desc) unless mocked?

          mock_spans[sp][:desc] = desc
        end

        def native_stop_span(span, time)
          return native_stop_span_without_mock(span, time) unless mocked?

          span = mock_spans[span]
          span[:duration] = time - span[:start]
          nil
        end

      end
    end

  end

end
