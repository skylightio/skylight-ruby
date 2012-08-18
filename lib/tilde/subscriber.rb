module Tilde
  # TODO: Handle filtering out notifications that we don't care about
  class Subscriber
    PROCESS_ACTION = "process_action.action_controller"

    def self.register!
      ActiveSupport::Notifications.subscribe nil, new
    end

    def start(name, id, payload)
      return unless trace = Trace.current

      if name == PROCESS_ACTION
        trace.endpoint = controller_action(payload)
      end

      trace.start(name, nil, payload)
    end

    def finish(name, id, payload)
      return unless trace = Trace.current
      trace.stop
    end

    def measure(name, id, payload)
      return unless trace = Trace.current
      trace.record(name, nil, payload)
    end

  private

    def controller_action(payload)
      "#{payload[:controller]}##{payload[:action]}"
    end

  end
end
