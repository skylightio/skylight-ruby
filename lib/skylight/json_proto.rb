require 'json'

module Skylight
  class JsonProto
    def initialize(config)
      @config = config
    end

    def write(out, from, counts, sample)

# {
#   batch: {
#     timestamp: 123456, // Second granularity
#     endpoints: [
#       {
#         name: "WidgetsController#index",
#         count: 100, // There can be a higher count # than there are traces
#         traces: [
#           {
#             // Trace UUID
#             uuid: "d11d7190-40cc-11e2-a25f-0800200c9a66",
#             spans: [
#               [
#                 null, // parent-id -- index of the parent span or null if root node
#                 0292352, // Span start timestamp in 0.1ms granularity, relative to the start of the trace
#                 20, // Duration of the span in 0.1ms granularity
#                 "action_controller.process", // Span category
#                 "Processing WidgetsController#index", // Span title, max 60 chars (optional)
#                 "", // Span description, string any size (optional)
#                 {}, // Map String->String
#               ],
#               [
#                 0, // The previous span is this span's parent
#                 1340923,
#                 0, // No duration
#                 "log.info", // category "foo" "\"foo\"
#                 "Title", // Title
#                 "Doing some stuff..." // Span description
#                 {}, // Map String->String
#               ]
#             ]
#           }
#         ]
#       },
#       // etc...
#     ]
#   }
# }

      hash = {
        :batch => {
          :timestamp => Util.clock.to_seconds(from),
        }
      }

      hash[:batch][:endpoints] = counts.map do |endpoint, count|
        ehash = {
          :name => endpoint,
          :count => count
        }

        traces = sample.select{|t| t.endpoint == endpoint }

        ehash[:traces] = traces.map do |t|
          # thash = { :uuid => t.ident }
          thash = { :uuid => "TODO" }

          thash[:spans] = t.spans.map do |s|
            [s.parent,
             s.started_at,
             s.ended_at - s.started_at,
             s.category,
             s.description,
             s.annotations
            ]
          end

          thash
        end

        ehash
      end

      require "pp"
      @config.logger.debug PP.pp(hash, "")

      out << hash.to_json
    end
  end
end
