module SpecHelper
  class MockTrace
    attr_accessor :endpoint, :segment
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

  def span(arg)
    Messages::Span.new(arg)
  end

  def event(cat, title = nil, desc = nil)
    Messages::Event.new(
      category:    cat,
      title:       title,
      description: desc
    )
  end
end
