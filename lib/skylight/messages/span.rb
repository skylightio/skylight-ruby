module Skylight
  module Messages
    class Span
      include Beefcake::Message

      required :event,       Event,      1
      repeated :annotations, Annotation, 2
      required :started_at,  :uint32,    3
      optional :duration,    :uint32,    4
      optional :children,    :uint32,    5

      # Bit of a hack
      attr_accessor :absolute_time

      # Optimization
      def initialize(attrs = nil)
        super if attrs
      end
    end
  end
end
