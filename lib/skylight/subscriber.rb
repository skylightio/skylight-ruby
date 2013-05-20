module Skylight
  class Subscriber

    def self.register!(config = Config.new)
      ActiveSupport::Notifications.subscribe nil, new(config)
    end

    attr_reader :config

    def initialize(config)
      @config = config
      @normalizers = Normalizers.build(config)
    end

    def start(name, id, payload)
      return unless trace = Instrumenter.current_trace

      cat, title, desc, annot = normalize(trace, name, payload)
      trace.start(now - gc_time, cat, title, desc, annot)

      trace
    end

    def finish(name, id, payload)
      return unless trace = Instrumenter.current_trace
      trace.stop(now - gc_time)
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
      Util::Clock.default.now
    end

  end
end
