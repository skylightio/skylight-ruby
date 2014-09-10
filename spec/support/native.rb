# This file should handle being loaded more than once. While this isn't really
# all that ideal, sometimes people like to glob the contents of spec/support.

unless ENV['SKYLIGHT_DISABLE_AGENT']
  # Attempt to load the native extension
  begin
    require 'skylight_native'
  rescue LoadError
    abort "Skylight Ruby extension is not present on the load path. This is " \
      "usually caused by not running the specs with Rake (`rake spec`). If running " \
      "the tests manually, ensure that the native extension is on the load path by " \
      "specifying where it resides with -I."
  end
end

# Reequire skylight proper
require 'skylight'

unless ENV['SKYLIGHT_DISABLE_AGENT']
  unless Skylight.native?
    abort "Failed to load the native Skylight agent. The currently configured " \
      "agent path is:\n\n    #{Skylight.libskylight_path}\n\n" \
      "Ensure that the native extension exists at that location or "\
      "specify the correct \nlocation with ENV['SKYLIGHT_LIB_PATH']\n\n"
  end

  # Make sure that skylightd is present
  skylightd = Skylight::Config::DEFAULTS[:'daemon.exec_path']

  unless skylightd && File.exist?(skylightd)
    abort "Failed to find skylightd. The currently configured " \
      "path is:\n\n    #{skylightd || "(no path specified)"}\n\n" \
      "Ensure that skylightd exists at this location or "\
      "specify the correct \nlocation with ENV['SKYLIGHT_LIB_PATH'] " \
      " (skylightd is expected to be alongside the lib location)\n\n"
  end
end
