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

      class Builder

        include Util::Logging

        attr_reader \
          :time,
          :category,
          :title,
          :started_at,
          :description,
          :annotations

        attr_accessor :children

        def initialize(trace, time, started_at, cat, title, desc, annot)
          @trace      = trace
          @built      = false
          @time       = time
          @started_at = started_at
          @category   = cat.to_s
          @children   = 0
          self.title  = title
          self.description = desc
        end

        def config
          @trace.config
        end

        def endpoint=(name)
          @trace.endpoint = name
        end

        def done
          @trace.done(self) unless built?
        rescue Exception => e
          error e.message
          t { e.backtrace.join("\n") }
        end

        def built?
          @built
        end

        def build(duration)
          @built = true
          Span.new(
            event: Event.new(
              category: category,
              title: title,
              description: description),
            annotations: to_annotations(annotations),
            started_at: @started_at,
            duration: duration && duration > 0 ? duration : nil,
            children: @children > 0 ? @children : nil)
        end

        def title=(val)
          val = nil unless val.respond_to?(:to_str)
          @title = val && val.to_str
        end

        def description=(val)
          val = nil unless val.respond_to?(:to_str)
          @description = val && val.to_str
        end

      private

        def to_annotations(val)
          [] # TODO: Implement
        end

      end
    end
  end
end
