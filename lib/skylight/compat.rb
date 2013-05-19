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

if defined?(ActiveSupport::Notifications::Fanout::Subscribers::Evented)
  # Handle early RCs of rails 4.0
  class ActiveSupport::Notifications::Fanout::Subscribers::Evented
    unless method_defined?(:publish)
      def publish(name, *args)
        if @delegate.respond_to?(:publish)
          @delegate.publish name, *args
        end
      end
    end
  end
end
