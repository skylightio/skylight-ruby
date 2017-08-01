module Skylight
  # Ensure the version of AS:N being used is recent enough
  begin
    # Attempt to reference an internal class only present in the new AS::Notifications
    ActiveSupport::Notifications::Fanout::Subscribers
  rescue NameError

    # The things we do...
    class ::ActiveSupport::Notifications::Fanout
      attr_reader :subscribers

      class Subscriber
        attr_reader :pattern, :delegate
      end
    end

    notifier = ActiveSupport::Notifications.notifier

    # If the class is missing, require our vendored AS::N
    require 'skylight/vendor/active_support/notifications'

    if notifier.subscribers.respond_to?(:each)
      notifier.subscribers.each do |sub|
        pattern  = sub.respond_to?(:pattern)  && sub.pattern
        delegate = sub.respond_to?(:delegate) && sub.delegate

        if pattern && delegate
          ActiveSupport::Notifications.subscribe(pattern, delegate)
        end
      end
    end
  end
end
