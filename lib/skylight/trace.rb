module Skylight
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

    def initialize(endpoint = "Unknown", start = Time.now)
      @endpoint = endpoint
      @start    = start
      @spans    = []
      @stack    = []
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
        super if attr
      end
    end

    def record(time, cat, title, desc, annot)
      span = build(time, cat, title, desc, annot)

      inc_children
      @stack << span

      self
    end

    def start(time, cat, title, desc, annot)
      span = build(time, cat, title, desc, annot)

      inc_children
      @stack << span

      self
    end

    def stop(time)
      unless span = @stack.pop
        raise "trace unbalanced"
      end

      span.ended_at = relativize(time)
      @spans << span

      self
    end

  private

    def build(time, cat, title, desc, annot)
      sp = Span.new
      sp.category    = cat
      sp.title       = title
      sp.description = desc
      sp.annotations = to_annotations(annot)
      sp.started_at  = relativize(time)
    end

    def inc_children
      return  unless span = @stack.last
      span.children = (span.children || 0) + 1
    end

    def to_annotations(annot)
      [] # TODO: Implement
    end

    def relativize(time)
      (1_000_000 * (time - now)).to_i
    end

  end
end
