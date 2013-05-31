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
        GC_CAT = 'noise.gc'.freeze

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
          start(@start, cat, cat, title, desc, annot)

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
                  start(now - gc_time, GC_CAT, GC_CAT)
                  stop(now, GC_CAT)
                end

                stop(now, cat)
              end
            end
          ensure
            gc.stop_track
          end
        end

        def record(time, cat, title = nil, desc = nil, annot = {})
          return if @busted
          return if :skip == cat

          time = adjust_for_skew(time)

          sp = span(time, nil, cat, title, desc, annot)

          inc_children
          @spans << sp.build(0)

          nil
        end

        def start(time, token, cat, title = nil, desc = nil, annot = {})
          return if @busted

          time = adjust_for_skew(time)

          sp = span(time, token, cat, title, desc, annot)

          push(sp)

          return if Skip === sp

          sp
        end

        def stop(time, token)
          return if @busted

          time = adjust_for_skew(time)

          sp = pop(token)

          unless sp.token == token
            @busted = true
            remaining = @stack.map { |sp| sp.token }
            raise TraceError, "#stop -- trace unbalanced; " \
              "got=#{token}; expected=#{sp.token}; " \
              "remaining=#{remaining.inspect}"
          end

          return if Skip === sp

          @spans << sp.build(relativize(time) - sp.started_at)

          nil
        end

        def build
          return if @busted
          unless @stack.empty?
            remaining = @stack.map { |sp| sp.token }
            raise TraceError, "trace unbalanced; remaining=#{remaining.inspect}"
          end

          Trace.new(
            uuid:     'TODO',
            endpoint: endpoint,
            spans:    spans)
        end

      private

        class Skip
          attr_reader :token

          def initialize(token)
            @token = token
          end
        end

        def span(time, token, cat, title, desc, annot)
          return Skip.new(token) if :skip == cat

          Span::Builder.new(
            self, time, token, relativize(time),
            cat, title, desc, annot)
        end

        def push(sp)
          @stack << sp

          unless Skip === sp
            inc_children
            @parents << sp
          end
        end

        def pop(token)
          unless sp = @stack.pop
            @busted = true
            raise TraceError, "closing span -- trace unbalanced; token=#{token}"
          end

          @parents.pop unless Skip === sp

          sp
        end

        def inc_children
          return unless sp = @parents.last
          sp.children += 1
        end

        def relativize(time)
          if parent = @parents[-1]
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

      end

    end
  end
end
