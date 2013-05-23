module SpecHelper

  def trace
    @trace ||= Skylight::Messages::Trace::Builder.new
  end

  def span(arg)
    if Hash === arg
      Skylight::Messages::Span.new(arg)
    else
      trace.spans[arg]
    end
  end

  def event(cat, title = nil, desc = nil)
    Skylight::Messages::Event.new(
      category:    cat,
      title:       title,
      description: desc)
  end

end
