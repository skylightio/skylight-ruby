module Skylight
  class Subscriber
    include Util::Logging

    attr_reader :config

    def initialize(config)
      @config      = config
      @subscriber  = nil
      @normalizers = Normalizers.build(config)
    end

    def register!
      unregister! if @subscriber
      @subscriber = ActiveSupport::Notifications.subscribe nil, self
    end

    def unregister!
      ActiveSupport::Notifications.unsubscribe @subscriber
      @subscriber = nil
    end

    def instrument(category, *args)
      return if :skip == category
      return unless trace = Instrumenter.current_trace

      annot = args.pop if Hash === args
      title = args.shift
      desc  = args.shift

      trace.start(now - gc_time, category, category, title, desc, annot)
    rescue Exception => e
      error "Subscriber#instrument error; msg=%s", e.message
      nil
    end

    def done(category)
      return unless trace = Instrumenter.current_trace
      trace.stop(now - gc_time, category)
    rescue Exception => e
      error "Subscriber#done error; msg=%s", e.message
      nil
    end

    #
    #
    # ===== ActiveSupport::Notifications API
    #
    #

    def start(name, id, payload)
      return unless trace = Instrumenter.current_trace

      cat, title, desc, annot = normalize(trace, name, payload)
      trace.start(now - gc_time, name, cat, title, desc, annot)
    rescue Exception => e
      error "Subscriber#start error; msg=%s", e.message
      nil
    end

    def finish(name, id, payload)
      return unless trace = Instrumenter.current_trace
      trace.stop(now - gc_time, name)
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

    def gc_time
      GC.update
      GC.time
    end

    def now
      Util::Clock.micros
    end

  end
end
