# This file should handle being loaded more than once. While this isn't really
# all that ideal, sometimes people like to glob the contents of spec/support.

require 'skylight/core'
require 'skylight/core/util/platform'

require 'skylight/instrumenter'
require 'skylight/trace'

unless ENV['SKYLIGHT_DISABLE_AGENT']
  ENV['SKYLIGHT_REQUIRED'] = 'true'

  begin
    require 'skylight/native'
  rescue LoadError => e
    abort "Skylight Ruby extension is not present on the load path.\n\n" \
      "Please run `rake build` first or run with `SKYLIGHT_DISABLE_AGENT=true`.\n\n" \
      "#{e.message}\n#{e.backtrace.join("\n")}" \
  end
end

# Load everything else
require 'skylight'
