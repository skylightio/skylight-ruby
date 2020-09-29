module SpecHelper
  module Messages
    class Batch
      include Beefcake::Message

      required :timestamp, :uint32,  1
      repeated :endpoints, Endpoint, 2
      optional :hostname,  :string,  3
      repeated :source_locations, :string, 4

      def source_location(span)
        if (val = span.annotation_val(:SourceLocation)&.string_val)
          file, line = val.split(":")
          [source_locations[file.to_i], line].compact.join(":")
        end
      end
    end
  end
end
