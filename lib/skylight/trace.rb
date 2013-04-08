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

    def initialize(endpoint = "Unknown", ident = nil)
      @ident      = ident
      @endpoint   = endpoint
      @spans      = []
      @timestamp  = nil
      @finish     = nil
      @stack      = []

      # Tracks the ID of the current parent
      @parent = nil
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

      # Set ended_at
      span.ended_at = now - @timestamp

      # Update the parent
      @parent = @spans[@parent].parent

      self
    end

    # Requires global synchronization
    def commit
      raise "trace unbalanced" if @parent

      @ident ||= gen_ident
      @finish = now

      # No more changes should be made
      freeze

      self
    end

  private

    def now
      Util.clock.now
    end

    def gen_ident
      Util::UUID.gen Digest::MD5.digest(@endpoint)[0, 2]
    end

    def build_span(cat, title, desc, annot)
      n = now
      @timestamp ||= n

      Span.new(@parent, n - @timestamp, cat, title, desc, annot)
    end

  end
end
