module Skylight
  module Messages
    class TraceEnvelope
      def self.deserialize(data)
        new(data)
      end

      attr_reader :data

      def initialize(data)
        @data = data
      end
    end
  end
end
