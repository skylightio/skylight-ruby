module Skylight
  module Messages
    class Span
      include Beefcake::Message

      optional :category,    String,     1
      optional :title,       String,     2
      optional :description, String,     3
      repeated :annotations, Annotation, 4
      required :started_at,  :uint32,    5
      optional :duration,    :uint32,    6
      optional :children,    :uint32,    7

      # Optimization
      def initialize(attrs = nil)
        super if attrs
      end
    end
  end
end
