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

      def to_simple_report
        endpoints_count = endpoints.count
        trace_count = endpoints.map { |endpoint| endpoint.traces.count }.sum

        if endpoints_count != 1 || trace_count != 1
          raise "`SimpleReport` should only be used on a batch size of 1; " \
            "found #{endpoints_count} endpoints and #{trace_count} traces."
        end

        SimpleReport.new(self)
      end

      # Provides accessors for commonly-used fields in specs. Assumes 1 endpoint and 1 trace.
      SimpleReport = Struct.new(:report) do
        def endpoint
          report.endpoints[0]
        end

        def trace
          endpoint.traces[0]
        end

        def spans
          trace.filter_spans
        end

        def mapped_spans
          spans.map do |span|
            [
              span.event.category,
              span.event.title,
              span.event.description,
              report.source_location(span)
            ]
          end
        end
      end
    end
  end
end
