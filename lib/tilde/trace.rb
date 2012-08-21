module Tilde
  class Trace
    KEY = :__tilde_current_trace

    def self.current
      Thread.current[KEY]
    end

    # Struct to track each span
    class Span < Struct.new(
      :parent,
      :started_at,
      :ended_at,
      :category,
      :description,
      :annotations)

      def key
        @key ||= [category, description]
      end
    end

    attr_reader :endpoint, :ident, :spans
    attr_writer :endpoint

    def initialize(endpoint = "Unknown", ident = nil)
      @ident    = ident
      @endpoint = endpoint
      @spans    = []

      # Tracks the ID of the current parent
      @parent = nil
    end

    def from
      return unless span = @spans.first
      span.started_at
    end

    def to
      return unless span = @spans.last
      span.ended_at
    end

    def record(cat, desc = nil, annot = nil)
      @spans << build_span(cat, desc, annot)
      self
    end

    def start(cat, desc = nil, annot = nil)
      span = build_span(cat, desc, annot)
      @parent = @spans.length

      @spans << span

      self
    end

    def stop
      raise "trace unbalanced" unless @parent

      # Track the time it ended
      @spans.last.ended_at = now
      # Update the parent
      @parent = @spans[@parent].parent

      self
    end

    # Requires global synchronization
    def commit
      raise "trace unbalanced" if @parent

      @ident ||= gen_ident

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

    def build_span(cat, desc, annot)
      n = now
      Span.new(@parent, n, n, cat, desc || "", annot)
    end

  end
end
