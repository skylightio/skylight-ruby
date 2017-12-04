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

if defined?(ActiveSupport::Notifications::Fanout::Subscribers::Evented)
  # Handle early RCs of rails 4.0
  # @api private
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

require 'rack'
require 'rack/etag'
if Rack.release.to_f < 1.6
  # Backport `close` compliance:
  #   https://github.com/rack/rack/commit/4d9e1b228dacbcf1552c68e2ab2f21274fdcecb4
  Rack::ETag.class_eval do
    def call(env)
      status, headers, body = @app.call(env)

      if etag_status?(status) && etag_body?(body) && !skip_caching?(headers)
        original_body = body
        digest, body = digest_body(body)
        original_body.close if original_body.respond_to?(:close)
        headers['ETag'] = %("#{digest}") if digest
      end

      unless headers['Cache-Control']
        if digest
          headers['Cache-Control'] = @cache_control if @cache_control
        else
          headers['Cache-Control'] = @no_cache_control if @no_cache_control
        end
      end

      [status, headers, body]
    end
  end
end
