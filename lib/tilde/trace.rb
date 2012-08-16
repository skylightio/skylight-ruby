module Tilde
  class Trace
    KEY = :__tilde_current_trace

    def self.current
      Thread.current[KEY]
    end

    # Struct to track each span
    class Span < Struct.new(
      :recorded_at,
      :parent,
      :category,
      :description,
      :annotations)
    end

    attr_reader :endpoint, :spans
    attr_writer :endpoint

    def initialize(endpoint = nil, ident = SecureRandom.uuid)
      @ident    = ident
      @endpoint = endpoint
      @spans    = []

      # Tracks the ID of the current parent
      @parent = nil
    end

    def from
      return unless span = @spans.first
      span.recorded_at
    end

    def to
      return unless span = @spans.last
      span.recorded_at
    end

    def record(cat, desc = nil, annot = nil)
      @spans << Span.new(Time.now, @parent, cat, desc, annot)
      self
    end

    def start(cat, desc = nil, annot = nil)
      span = Span.new(Time.now, @parent, cat, desc, annot)
      @parent = @spans.length

      @spans << span

      self
    end

    def stop
      raise "trace unbalanced" unless @parent
      @parent = @spans[@parent].parent
      self
    end

    # Requires global synchronization
    def commit
      raise "trace unbalanced" if @parent

      # No more changes should be made
      freeze

      self
    end

  end
end
