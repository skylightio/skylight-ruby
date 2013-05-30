require 'skylight/messages/base'

module Skylight
  module Messages
    class Trace < Base

      required :uuid,     :string, 1
      optional :endpoint, :string, 2
      repeated :spans,    Span,    3

      def valid?
        return false unless spans && spans.length > 0
        spans[-1].started_at == 0
      end

      class Builder
        include Util::Logging

        attr_accessor :endpoint
        attr_reader   :spans, :config

        def initialize(endpoint = "Unknown", start = Util::Clock.micros, config = nil)
          @endpoint = endpoint
          @busted   = false
          @config   = config
          @start    = start
          @spans    = []
          @stack    = []
          @parents  = []

          # Track time
          @last_seen_time = start
        end

        def root(cat, title = nil, desc = nil, annot = {})
          return unless block_given?
          return yield unless @stack == []
          return yield unless config

          gc = config.gc
          start(@start, cat, title, desc, annot)

          begin
            gc.start_track

            begin
              yield
            ensure
              unless @busted
                now = Util::Clock.micros

                GC.update
                gc_time = GC.time

                if gc_time > 0
                  t { fmt "tracking GC time; duration=%d", gc_time }
                  start(now - gc_time, 'noise.gc')
                  stop(now)
                end

                stop(now)
              end
            end
          ensure
            gc.stop_track
          end
        end

        def record(time, cat, title = nil, desc = nil, annot = {})
          return if @busted

          time = adjust_for_skew(time)

          sp = span(time, cat, title, desc, annot)

          return self if :skip == sp

          inc_children
          @spans << sp

          self
        end

        def start(time, cat, title = nil, desc = nil, annot = {})
          return if @busted

          time = adjust_for_skew(time)

          sp = span(time, cat, title, desc, annot)

          push(sp)

          self
        end

        def stop(time)
          return if @busted

          time = adjust_for_skew(time)

          sp = pop

          return self if :skip == sp

          sp.duration = relativize(time) - sp.started_at
          @spans << sp

          self
        end

        def build
          return if @busted
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
          sp.event         = event(cat, title, desc)
          sp.annotations   = to_annotations(annot)
          sp.started_at    = relativize(time)
          sp.absolute_time = time

          if sp.started_at < 0
            @busted = true
            raise TraceError, "[BUG] span started_at negative; event=#{cat};" \
              " started_at=#{sp.started_at};" \
              " duration=#{sp.duration}"
          end

          sp
        end

        def event(cat, title, desc)
          title = nil unless title.respond_to?(:to_str)
          desc  = nil unless desc.respond_to?(:to_str)

          Event.new(
            category:    cat.to_s,
            title:       title && title.to_str,
            description: desc && desc.to_str)
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
            @busted = true
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
          if parent = @parents[-1]
            ((time - parent.absolute_time) / 100).to_i
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

      end

    end
  end
end
