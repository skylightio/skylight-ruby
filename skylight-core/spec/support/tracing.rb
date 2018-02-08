module SpecHelper

  class MockTrace
    attr_accessor :endpoint
    attr_writer :instrumenter

    def initialize
      @endpoint = "Rack"
    end

    def instrumenter
      raise "missing instrumenter" unless @instrumenter
      @instrumenter
    end

  end

  def trace
    @trace ||= MockTrace.new
  end

  # FIXME: This method does two different things and the second branch only works
  # with a special override of the trace method.
  def span(arg)
    if Hash === arg
      Messages::Span.new(arg)
    else
      trace.spans[arg]
    end
  end

  def event(cat, title = nil, desc = nil)
    Messages::Event.new(
      category:    cat,
      title:       title,
      description: desc)
  end
end
