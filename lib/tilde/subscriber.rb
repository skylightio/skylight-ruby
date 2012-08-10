module Tilde
  class Subscriber

    def self.register!(instrumenter)
      ActiveSupport::Notifications.subscribe nil, new(instrumenter)
    end

    def initialize(instrumenter)
      @instrumenter = instrumenter
    end

    def start(name, id, payload)
      process(name, payload, false)
    end

    def finish(name, id, payload)
      # p [ :GOT, name ]
    end

    def measure(name, id, payload)
      process(name, payload, true)
    end

  private

    def process(name, payload, is_leaf)
      if name == 'sql.active_record'
        return if payload[:name] == 'SCHEMA'
      end

      puts "~~~~~~~~~~~~~~~~~~ [#{is_leaf ? "LEAF" : "BRANCH"}] #{name} ~~~~~~~~~~~~~~~~~~~~~"
      p payload
      puts
    end

  end
end
