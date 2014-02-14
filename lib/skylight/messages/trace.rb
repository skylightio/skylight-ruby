module Skylight
  module Messages
    class Trace
      class Builder
        GC_CAT = 'noise.gc'.freeze

        include Util::Logging

        attr_reader   :endpoint, :spans, :notifications

        def endpoint=(value)
          @endpoint = value.freeze
          @native_builder.native_set_name(value)
        end

        def initialize(instrumenter, endpoint, start, cat, title=nil, desc=nil, annot=nil)
          raise ArgumentError, 'instrumenter is required' unless instrumenter

          start = normalize_time(start)

          @native_builder = ::Skylight::Trace.native_new(start, "TODO")
          @native_builder.native_set_name(endpoint)

          @instrumenter  = instrumenter
          @endpoint      = endpoint.freeze
          @submitted     = false
          @start         = start

          @notifications = []

          if Hash === title
            annot = title
            title = desc = nil
          elsif Hash === desc
            annot = desc
            desc = nil
          end

          # create the root node
          @root = @native_builder.native_start_span(@start, cat)
          @native_builder.native_span_set_title(@root, title) if title
          @native_builder.native_span_set_description(@root, desc) if desc

          @gc   = config.gc.track unless ENV.key?("SKYLIGHT_DISABLE_GC_TRACKING")
        end

        def serialize
          raise "Can only serialize once" if @serialized
          @serialized = true
          @native_builder.native_serialize
        end

        def config
          @instrumenter.config
        end

        def record(cat, title=nil, desc=nil, annot=nil)
          if Hash === title
            annot = title
            title = desc = nil
          elsif Hash === desc
            annot = desc
            desc = nil
          end

          title.freeze
          desc.freeze

          desc = @instrumenter.limited_description(desc)

          time = Util::Clock.nanos - gc_time

          stop(start(time, cat, title, desc), time)

          nil
        end

        def instrument(cat, title=nil, desc=nil, annot=nil)
          if Hash === title
            annot = title
            title = desc = nil
          elsif Hash === desc
            annot = desc
            desc = nil
          end

          title.freeze
          desc.freeze

          original_desc = desc
          now           = Util::Clock.nanos
          desc          = @instrumenter.limited_description(desc)

          if desc == Instrumenter::TOO_MANY_UNIQUES
            debug "[SKYLIGHT] [#{Skylight::VERSION}] A payload description produced <too many uniques>"
            debug "original desc=%s", original_desc
            debug "cat=%s, title=%s, desc=%s, annot=%s", cat, title, desc, annot.inspect
          end

          start(now - gc_time, cat, title, desc, annot)
        end

        def done(span)
          return unless span
          stop(span, Util::Clock.nanos - gc_time)
        end

        def release
          return unless @instrumenter.current_trace == self
          @instrumenter.current_trace = nil
        end

        def traced
          time = gc_time
          now = Util::Clock.nanos

          if time > 0
            t { fmt "tracking GC time; duration=%d", time }
            stop(start(now - time, GC_CAT, nil, nil, {}), now)
          end

          stop(@root, now)
        end

        def submit
          return if @submitted

          release
          @submitted = true

          traced

          @instrumenter.process(@native_builder)
        rescue Exception => e
          error e
          t { e.backtrace.join("\n") }
        end

      private

        def start(time, cat, title, desc, annot=nil)
          span(normalize_time(time), cat, title, desc, annot)
        end

        def stop(span, time)
          @native_builder.native_stop_span(span, normalize_time(time))
          nil
        end

        def normalize_time(time)
          time.to_i / 100_000
        end

        def span(time, cat, title=nil, desc=nil, annot=nil)
          sp = @native_builder.native_start_span(time, cat.to_s)
          @native_builder.native_span_set_title(sp, title.to_s) if title
          @native_builder.native_span_set_description(sp, desc.to_s) if desc
          sp
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
