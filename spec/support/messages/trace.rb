module SpecHelper
  module Messages
    class Trace
      include Beefcake::Message

      required :uuid, :string, 1
      optional :endpoint, :string, 2
      repeated :spans, Span, 3

      def filter_spans
        block_given? ? spans.select { |span| yield span } : spans.reject { |span| span.event.category == "noise.gc" }
      end
    end
  end
end
