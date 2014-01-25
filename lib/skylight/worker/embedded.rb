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
        # a Rust Trace
        if msg.respond_to?(:native_serialize)
          msg = Messages::TraceEnvelope.new(msg.native_serialize)
        end

        @collector.submit(msg)
      end
    end
  end
end
