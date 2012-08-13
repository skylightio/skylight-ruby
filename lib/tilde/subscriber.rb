module Tilde
  class Subscriber

    def self.register!
      ActiveSupport::Notifications.subscribe nil, new
    end

    def start(name, id, payload)
      return unless trace = Trace.current
      trace.start(name, id, payload)
    end

    def finish(name, id, payload)
      return unless trace = Trace.current
      trace.stop
    end

    def measure(name, id, payload)
      return unless trace = Trace.current
      trace.record(name, id, payload)
    end

  end
end
