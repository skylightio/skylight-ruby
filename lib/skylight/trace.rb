module Skylight
  # The first span will always have a timestamp of 0, which other
  # spans will report times relative to.
  #
  # build_span will lazily start the timestamp at 0
  class Trace
    KEY = :__skylight_current_trace

    def self.current
      Thread.current[KEY]
    end

    # Struct to track each span
    class Span < Struct.new(
      :parent,
      :started_at,
      :category,
      :title,
      :description,
      :annotations,
      :ended_at)

      def key
        @key ||= [category, description]
      end
    end

    attr_reader :endpoint, :ident, :spans
    attr_writer :endpoint

    def initialize(config = Config.new, endpoint = "Unknown", ident = nil)
      @config     = config
      @ident      = ident
      @endpoint   = endpoint
      @spans      = []
      @timestamp  = nil
      @finish     = nil
      @stack      = []

      # Tracks the ID of the current parent
      @parent = nil

      # Track the cumulative amount of GC removed from traces
      @cumulative_gc = 0
    end

    def from
      return unless @finish
      @timestamp
    end

    def to
      @finish
    end

    def record(cat, title, desc, annot)
      return self if cat == :skip

      span = build_span(cat, title, desc, annot)
      span.ended_at = span.started_at

      @spans << span

      self
    end

    def start(cat, title, desc, annot)
      @stack.push cat
      return self if cat == :skip

      # TODO: Allocate GC time to all running threads
      @config.gc_profiler.clear

      span = build_span(cat, title, desc, annot)

      @parent = @spans.length

      @spans << span

      self
    end

    def stop
      last = @stack.pop
      return self if last == :skip

      # Find last unclosed span
      span = @spans.last
      while span && span.ended_at
        span = span.parent ? @spans[span.parent] : nil
      end

      raise "trace unbalanced" unless span

      @cumulative_gc += convert(@config.gc_profiler.total_time)
      @config.gc_profiler.clear

      span.ended_at = now - @timestamp - @cumulative_gc

      # Update the parent
      @parent = @spans[@parent].parent

      self
    end

    # Requires global synchronization
    def commit
      raise "trace unbalanced" if @parent

      n = now

      if @cumulative_gc > 0
        span = Span.new(0, n - @timestamp - @cumulative_gc, "noise.gc", nil, nil, nil)
        span.ended_at = n - @timestamp
        @spans << span
      end

      @ident ||= gen_ident
      @finish = n

      # No more changes should be made
      freeze

      self
    end

  private

    def now
      Util.clock.now
    end

    def convert(ms)
      # TODO: Ruby 2.0 uses seconds here :(
      Util.clock.convert(ms / 1000.0)
    end

    def gen_ident
      Util::UUID.gen Digest::MD5.digest(@endpoint)[0, 2]
    end

    def build_span(cat, title, desc, annot)
      n = now - @cumulative_gc
      @timestamp ||= n

      Span.new(@parent, n - @timestamp, cat, title, desc, annot)
    end

  end
end
