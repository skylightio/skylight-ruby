module Skylight
  class Subscriber
    include Util::Logging

    attr_reader :config

    def initialize(config, instrumenter)
      @config       = config
      @subscriber   = nil
      @normalizers  = Normalizers.build(config)
      @instrumenter = instrumenter
    end

    def register!
      unregister! if @subscriber
      @subscriber = ActiveSupport::Notifications.subscribe nil, self
    end

    def unregister!
      ActiveSupport::Notifications.unsubscribe @subscriber
      @subscriber = nil
    end

    #
    #
    # ===== ActiveSupport::Notifications API
    #
    #

    class Notification
      attr_reader :name, :span

      def initialize(name, span)
        @name, @span = name, span
      end
    end

    def start(name, id, payload)
      return unless trace = @instrumenter.current_trace

      cat, title, desc, annot = normalize(trace, name, payload)

      if error = annot[:skylight_error]
        @instrumenter.error(*error)
      end

      unless cat == :skip
        span = trace.instrument(cat, title, desc, annot)
      end

      trace.notifications << Notification.new(name, span)

    rescue Exception => e
      error "Subscriber#start error; msg=%s", e.message
      nil
    end

    def finish(name, id, payload)
      return unless trace = @instrumenter.current_trace

      while curr = trace.notifications.pop
        if curr.name == name
          curr.span.done if curr.span
          return
        end
      end

    rescue Exception => e
      error "Subscriber#finish error; msg=%s", e.message
      nil
    end

    def publish(name, *args)
      # Ignored for now because nothing in rails uses it
    end

  private

    def normalize(*args)
      @normalizers.normalize(*args)
    end

  end
end
