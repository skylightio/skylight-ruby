module SpecHelper

  class MockInstrumenter
    attr_reader :config, :traces

    def initialize(config)
      @config = config
      @traces = []
    end

    def trace
      traces.last
    end

    def process(t)
      @traces << t
    end

    attr_accessor :current_trace

    def limited_description(desc)
      desc
    end
  end

  def instrumenter
    @instrumenter ||= MockInstrumenter.new(config)
  end

  def trace
    @trace ||= Skylight::Messages::Trace::Builder.new instrumenter, 'Rack', clock.nanos, 'app.rack.request'
  end

  def span(arg)
    if Hash === arg
      SpecHelper::Messages::Span.new(arg)
    else
      trace.spans[arg]
    end
  end

  def event(cat, title = nil, desc = nil)
    SpecHelper::Messages::Event.new(
      category:    cat,
      title:       title,
      description: desc)
  end

end
