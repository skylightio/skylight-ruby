module Skylight::Core
  # @api private
  class Subscriber
    include Util::Logging

    attr_reader :config

    def initialize(config, instrumenter)
      @config       = config
      @normalizers  = Normalizers.build(config)
      @instrumenter = instrumenter
      @subscribers  = []
    end

    def register!
      unregister!
      @normalizers.keys.each do |key|
        @subscribers << ActiveSupport::Notifications.subscribe(key, self)
      end
    end

    def unregister!
      until @subscribers.empty?
        ActiveSupport::Notifications.unsubscribe @subscribers.shift
      end
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
      return if @instrumenter.disabled?
      return unless (trace = @instrumenter.current_trace)

      result = normalize(trace, name, payload)

      unless result == :skip
        case result.size
        when 3, 4
          cat, title, desc, meta = result
        else
          raise "Invalid normalizer result: #{result.inspect}"
        end

        span = trace.instrument(cat, title, desc, meta)
      end

      trace.notifications << Notification.new(name, span)
    rescue Exception => e
      error "Subscriber#start error; msg=%s", e.message
      debug "trace=%s", trace.inspect
      debug "in:  name=%s", name.inspect
      debug "in:  payload=%s", payload.inspect
      debug "out: cat=%s, title=%s, desc=%s", cat.inspect, name.inspect, desc.inspect
      t { e.backtrace.join("\n") }
      nil
    end

    def finish(name, id, payload)
      return if @instrumenter.disabled?
      return unless (trace = @instrumenter.current_trace)

      while (curr = trace.notifications.pop)
        if curr.name == name
          begin
            normalize_after(trace, curr.span, name, payload)
          ensure
            meta = {}
            meta[:exception] = payload[:exception] if payload[:exception]
            meta[:exception_object] = payload[:exception_object] if payload[:exception_object]
            trace.done(curr.span, meta) if curr.span
          end
          return
        end
      end
    rescue Exception => e
      error "Subscriber#finish error; msg=%s", e.message
      debug "trace=%s", trace.inspect
      debug "in:  name=%s", name.inspect
      debug "in:  payload=%s", payload.inspect
      t { e.backtrace.join("\n") }
      nil
    end

    def publish(name, *args)
      # Ignored for now because nothing in rails uses it
    end

    private

      def normalize(*args)
        @normalizers.normalize(*args)
      end

      def normalize_after(*args)
        @normalizers.normalize_after(*args)
      end
  end
end
