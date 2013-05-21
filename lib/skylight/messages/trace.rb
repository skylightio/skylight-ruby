require 'skylight/messages/base'

module Skylight
  module Messages
    class TraceError < RuntimeError; end

    class Trace < Base

      required :uuid,     :string, 1
      optional :endpoint, :string, 2
      repeated :spans,    Span,    3

      class Builder
        attr_accessor :endpoint
        attr_reader   :spans, :start

        def initialize(endpoint = "Unknown", start = Util::Clock.now)
          @endpoint = endpoint
          @start    = start
          @spans    = []
          @stack    = []
          @parents  = []
        end

        def record(time, cat, title = nil, desc = nil, annot = {})
          sp = span(time, cat, title, desc, annot)

          return self if :skip == sp

          inc_children
          @spans << sp

          self
        end

        def start(time, cat, title = nil, desc = nil, annot = {})
          sp = span(time, cat, title, desc, annot)

          push(sp)

          self
        end

        def stop(time)
          sp = pop

          return self if :skip == sp

          sp.duration = relativize(time) - sp.started_at
          @spans << sp

          self
        end

        def build
          raise TraceError, "trace unbalanced" unless @stack.empty?

          Trace.new(
            uuid:     'TODO',
            endpoint: endpoint,
            spans:    spans)
        end

      private

        def span(time, cat, title, desc, annot)
          return cat if :skip == cat

          sp = Span.new
          sp.category    = cat.to_s
          sp.title       = title
          sp.description = desc
          sp.annotations = to_annotations(annot)
          sp.started_at  = relativize(time)
          sp
        end

        def push(sp)
          @stack << sp

          unless :skip == sp
            inc_children
            @parents << sp
          end
        end

        def pop
          unless sp = @stack.pop
            raise TraceError, "trace unbalanced"
          end

          @parents.pop if :skip != sp

          sp
        end

        def inc_children
          return unless sp = @parents.last
          sp.children = (sp.children || 0) + 1
        end

        def to_annotations(annot)
          [] # TODO: Implement
        end

        def relativize(time)
          (1_000_000 * (time - @start)).to_i
        end

      end

    end
  end
end
