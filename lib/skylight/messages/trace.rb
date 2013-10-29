require 'skylight/messages/base'

module Skylight
  module Messages
    class Trace < Base

      required :uuid,     :string, 1
      optional :endpoint, :string, 2
      repeated :spans,    Span,    3

      class Builder
        GC_CAT = 'noise.gc'.freeze

        include Util::Logging

        attr_accessor :endpoint
        attr_reader   :spans, :notifications

        def initialize(instrumenter, endpoint, start, cat, *args)
          raise ArgumentError, 'instrumenter is required' unless instrumenter

          @instrumenter = instrumenter
          @endpoint     = endpoint
          @start        = start
          @spans        = []
          @stack        = []
          @submitted    = false

          # Tracks the AS::N stack
          @notifications = []

          # Track time
          @last_seen_time = start

          annot = args.pop if Hash === args
          title = args.shift
          desc  = args.shift

          # Create the root node
          @root = start(@start, cat, title, desc, annot)
          @gc   = config.gc.track
        end

        def config
          @instrumenter.config
        end

        def record(cat, *args)
          annot = args.pop if Hash === args
          title = args.shift
          desc  = args.shift
          now   = adjust_for_skew(Util::Clock.micros)

          desc = @instrumenter.limited_description(desc)

          sp = span(now - gc_time, cat, title, desc, annot)
          inc_children
          @spans << sp.build(0)

          nil
        end

        def instrument(cat, *args)
          annot = args.pop if Hash === args.last
          title = args.shift
          desc  = args.shift
          now   = adjust_for_skew(Util::Clock.micros)

          desc = @instrumenter.limited_description(desc)

          start(now - gc_time, cat, title, desc, annot)
        end

        def done(span)
          return unless span
          stop(span, adjust_for_skew(Util::Clock.micros) - gc_time)
        end

        def release
          return unless @instrumenter.current_trace == self
          @instrumenter.current_trace = nil
        end

        def submit
          return if @submitted

          release
          @submitted = true

          now = adjust_for_skew(Util::Clock.micros)

          # Pop everything that is left
          while sp = pop
            @spans << sp.build(relativize(now) - sp.started_at)
          end

          time = gc_time

          if time > 0
            t { fmt "tracking GC time; duration=%d", time }
            noise = start(now - time, GC_CAT, nil, nil, {})
            stop(noise, now)
          end

          if sp = @stack.pop
            @spans << sp.build(relativize(now) - sp.started_at)
          end

          t = Trace.new(
            uuid:     'TODO',
            endpoint: endpoint,
            spans:    spans)

          @instrumenter.process(t)
        rescue Exception => e
          error e
          t { e.backtrace.join("\n") }
        end

      private

        def start(time, cat, title, desc, annot)
          sp = span(time, cat, title, desc, annot)

          push(sp)

          sp
        end

        def stop(span, time)
          until span == (sp = pop)
            return unless sp
            @spans << sp.build(relativize(time) - sp.started_at)
          end

          @spans << span.build(relativize(time) - sp.started_at)

          nil
        end

        def span(time, cat, title, desc, annot)
          Span::Builder.new(
            self, time, relativize(time),
            cat, title, desc, annot)
        end

        def pop
          return unless @stack.length > 1
          @stack.pop
        end

        def push(sp)
          inc_children
          @stack << sp
        end

        def inc_children
          return unless sp = @stack[-1]
          sp.children += 1
        end

        def relativize(time)
          if parent = @stack[-1]
            ((time - parent.time) / 100).to_i
          else
            ((time - @start) / 100).to_i
          end
        end

        # Sadely, we don't have access to a pure monotonic clock in ruby, so we
        # need to cheat a little.
        def adjust_for_skew(time)
          if time <= @last_seen_time
            return @last_seen_time
          end

          @last_seen_time = time
          time
        end

        def gc_time
          return 0 unless @gc
          @gc.update
          @gc.time
        end

      end
    end
  end
end
