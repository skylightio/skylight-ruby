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

      name, payload = Normalize.normalize(trace, name, payload)

      logger.debug("[SKYLIGHT] START: #{name} - #{payload.inspect}")
      trace.start(name, nil, payload)
    end

    def finish(name, id, payload)
      return unless trace = Trace.current

      logger.debug("[SKYLIGHT] END: #{name} - #{payload.inspect}")
      trace.stop
    end

    def measure(name, id, payload)
      return unless trace = Trace.current

      logger.debug("[SKYLIGHT] MEASURE: #{name} - #{payload.inspect}")
      trace.record(name, nil, payload)
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
