module Skylight
  module Messages
    class TraceEnvelope
      def self.decode(data)
        new(data)
      end

      attr_reader :data

      def initialize(data)
        @data = data
      end
    end

    Messages.set(Trace.message_id, TraceEnvelope)
  end
end
