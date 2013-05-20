module Skylight
  class TraceError < RuntimeError; end

  class Trace
    KEY = :__skylight_current_trace

    def self.current
      Thread.current[KEY]
    end

    def self.current=(trace)
      Thread.current[KEY] = trace
    end

    attr_accessor :endpoint
    attr_reader   :spans

    def initialize(endpoint = "Unknown", start = Util::Clock.default.now)
      @endpoint = endpoint
      @start    = start
      @spans    = []
      @stack    = []
      @parents  = []
    end

    class Annotation
      include Beefcake::Message

      optional :key,    String,     1
      optional :int,    :int64,     2
      optional :double, :double,    3
      optional :string, String,     4
      repeated :nested, Annotation, 5
    end

    class Span
      include Beefcake::Message

      required :category,    String,     1
      optional :title,       String,     2
      optional :description, String,     3
      repeated :annotations, Annotation, 4
      required :started_at,  :uint32,    5
      optional :ended_at,    :uint32,    6
      optional :children,    :uint32,    7

      # Optimization
      def initialize(attrs = nil)
        super if attrs
      end
    end

    def record(time, cat, title = nil, desc = nil, annot = {})
      span = build(time, cat, title, desc, annot)

      return self if :skip == span

      inc_children
      @spans << span

      self
    end

    def start(time, cat, title = nil, desc = nil, annot = {})
      span = build(time, cat, title, desc, annot)

      push(span)

      self
    end

    def stop(time)
      span = pop

      return self if :skip == span

      span.ended_at = relativize(time)
      @spans << span

      self
    end

    def commit
      raise TraceError, "trace unbalanced" unless @stack.empty?
      freeze
      self
    end

  private

    def build(time, cat, title, desc, annot)
      return cat if :skip == cat

      sp = Span.new
      sp.category    = cat.to_s
      sp.title       = title
      sp.description = desc
      sp.annotations = to_annotations(annot)
      sp.started_at  = relativize(time)
      sp
    end

    def push(span)
      @stack << span

      unless :skip == span
        inc_children
        @parents << span
      end
    end

    def pop
      unless span = @stack.pop
        raise TraceError, "trace unbalanced"
      end

      @parents.pop if :skip != span

      span
    end

    def inc_children
      return unless span = @parents.last
      span.children = (span.children || 0) + 1
    end

    def to_annotations(annot)
      [] # TODO: Implement
    end

    def relativize(time)
      (1_000_000 * (time - @start)).to_i
    end

  end
end
