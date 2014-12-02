# This file should handle being loaded more than once. While this isn't really
# all that ideal, sometimes people like to glob the contents of spec/support.

require 'skylight/util/platform'

# We build skylight_native here for testing
$native_lib_path = File.expand_path("../../../target/#{Skylight::Util::Platform.tuple}", __FILE__)
$LOAD_PATH << $native_lib_path

unless ENV['SKYLIGHT_DISABLE_AGENT']
  ENV['SKYLIGHT_REQUIRED'] = 'true'

  # Attempt to load the native extension
  begin
    require 'skylight/native'

    module Skylight
      class Instrumenter
        alias native_submit_trace_without_mock native_submit_trace
        alias native_stop_without_mock native_stop

        def self.mock!(&callback)
          @instance = self.allocate.tap do |inst|
            inst.instance_eval do
              initialize Config.new(mock_submission: callback || proc {})
              @subscriber.register!
            end
          end
        end

        def native_submit_trace(trace)
          if config.key?(:mock_submission)
            config[:mock_submission].call(trace)
          else
            native_submit_trace_without_mock(trace)
          end
        end

        def native_stop
          native_stop_without_mock unless config.key?(:mock_submission)
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
