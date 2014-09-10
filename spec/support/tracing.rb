module SpecHelper

  class MockTrace
    attr_accessor :endpoint

    def initialize
      @endpoint = "Rack"
    end
  end

  def trace
    @trace ||= MockTrace.new
  end

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
