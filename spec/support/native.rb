# This file should handle being loaded more than once. While this isn't really
# all that ideal, sometimes people like to glob the contents of spec/support.

require 'skylight/util/platform'

# We build skylight_native here for testing
$native_lib_path = File.expand_path("../../../target/#{Skylight::Util::Platform.tuple}", __FILE__)
$LOAD_PATH << $native_lib_path

unless ENV['SKYLIGHT_DISABLE_AGENT']
  ENV['SKYLIGHT_REQUIRED'] = 'true'

  require 'skylight'

  begin
    module Skylight
      class Instrumenter
        alias native_submit_trace_without_mock native_submit_trace
        alias native_stop_without_mock native_stop
        alias limited_description_without_mock limited_description

        def self.mock!(&callback)
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
  rescue LoadError => e
    abort "Skylight Ruby extension is not present on the load path.\n\n" \
      "Please run `rake build` first or run with `SKYLIGHT_DISABLE_AGENT=true`.\n\n" \
      "#{e.message}\n#{e.backtrace.join("\n")}" \
  end
end


# Load everything else
require 'skylight'
