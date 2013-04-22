module Skylight
  # TODO: Handle filtering out notifications that we don't care about
  class Subscriber
    def self.register!(config=Config.new)
      ActiveSupport::Notifications.subscribe nil, new(config)
    end

    def initialize(config)
      @config = config
    end

    def start(name, id, payload)
      return unless trace = Trace.current

      name, title, desc, payload = Normalize.normalize(trace, name, payload, @config.normalizer)

      trace.start(name, title, desc, payload)
    end

    def finish(name, id, payload)
      return unless trace = Trace.current

      logger.debug("[SKYLIGHT] END")
      trace.stop
    end

    def measure(name, id, payload)
      return unless trace = Trace.current

      name, title, desc, payload = Normalize.normalize(trace, name, payload)

      trace.record(name, title, desc, payload)
    end

  private

    def controller_action(payload)
      "#{payload[:controller]}##{payload[:action]}"
    end

    def logger
      @config.logger
    end
  end
end
