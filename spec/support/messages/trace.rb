module SpecHelper
  module Messages
    class Trace
      include Beefcake::Message

      required :uuid,     :string, 1
      optional :endpoint, :string, 2
      repeated :spans,    Span,    3

      def filter_spans
        if block_given?
          spans.select { |span| yield span }
        else
          spans.reject { |span| span.event.category == "noise.gc" }
        end
      end
    end
  end
end
