class TraceBuilder
  include Skylight::Messages

  @id = 0

  def self.build(endpoint="rack", &block)
    @id += 1
    trace = Trace.new(uuid: @id.to_s, endpoint: endpoint, spans: [])
    new(trace).instance_eval(&block)
    trace
  end

  def initialize(trace)
    @trace = trace
  end

  def span(category, title, description, &block)
    @trace.spans << SpanBuilder.build(&block)
  end

  class SpanBuilder
    def self.build(category, title, description, &block)
      span = Span.new
      span.event = Event.new(category, title, description)
      new(span).instance_eval(&block)
      span
    end

    def initialize(span)
      @span = span
    end
  end
end
