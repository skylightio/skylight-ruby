module Skylight
  # Ensure the version of AS:N being used is recent enough
  begin
    # Attempt to reference an internal class
    ActiveSupport::Notifications::Fanout::Subscribers
  rescue NameError
    # If the class is missing, require our vendored AS::N
    require 'skylight/vendor/active_support/notifications'
  end
end
