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

      def endpoint_name
        Skylight::Trace.native_name_from_serialized(@data)
      end
    end
  end
end
