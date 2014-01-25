module Skylight
  module Worker
    class Embedded
      def initialize(collector)
        @collector = collector
      end

      def spawn
        @collector.spawn
      end

      def shutdown
        @collector.shutdown
      end

      def submit(msg)
        decoder = Messages::ID_TO_KLASS.fetch(Messages::KLASS_TO_ID.fetch(msg.class))
        msg = decoder.deserialize(msg.serialize)

        @collector.submit(msg)
      end
    end
  end
end
